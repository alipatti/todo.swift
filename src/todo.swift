import ArgumentParser
import EventKit
import Foundation
import Swiftline
import SwiftyChrono

// icons for command line output
let FLAG = "" // \uf024
let CALENDAR = "" // \uf133

let NOW = Date()
let WIDTH = 80 // TODO: make this the width of the console

let HORIZONTAL_DIVIDER = "═"
let BANNER =
    """
    ooooooooooooo   .oooooo.   oooooooooo.     .oooooo.
    8'   888   `8  d8P'  `Y8b  `888'   `Y8b   d8P'  `Y8b
         888      888      888  888      888 888      888
         888      888      888  888      888 888      888
         888      888      888  888      888 888      888
         888      `88b    d88'  888     d88' `88b    d88'
        o888o      `Y8bood8P'  o888bood8P'    `Y8bood8P'
    """

let PRIORITIES = [
    "none": 0,
    "low": 9,
    "med": 5,
    "high": 1,
]
let CHRONO = Chrono()

@main
struct Todo: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A command line app to manage your Apple reminders.",

        version: "0.1.0",

        subcommands: [Add.self, List.self] // TODO: add edit functionality
    )
}

struct Add: AsyncParsableCommand {
    @Argument(help: "The title of the reminder.")
    var title: String

    @Option(name: .shortAndLong, help: "The notes associated with the reminder.")
    var notes: String?

    @Option(name: .shortAndLong,
            help: "The due date of the reminder. Supports natural language input, e.g. 'next friday'.")
    var dueDate: String?

    @Option(name: .shortAndLong, help: "The list to add the reminder to.")
    var list: String?

    // TODO: incorporate this. default priority should be low, with options to set to med or high
    @Option(name: .shortAndLong, help: "The priority of the reminder.")
    var priority: String = "low" // | "high" | "med"

    func run() async throws {
        let store = try await getStore()
        let task = EKReminder(eventStore: store)

        task.title = title

        if let list {
            task.calendar = getCalendar(list, store: store)
        } else {
            task.calendar = store.defaultCalendarForNewReminders()
        }

        task.notes = notes

        if let p = PRIORITIES[priority] { task.priority = p }
        else { fatalError("Invalid priority: \(priority)") }

        if let dueDate {
            let date = parseDate(dueDate)
            task.dueDateComponents = Calendar.current.dateComponents([.day, .year, .month], from: date)
        }

        try store.save(task, commit: true)

        printReminder(task) // TODO: print more helpful/prettier message
    }
}

struct List: AsyncParsableCommand {
    @Option(name: .shortAndLong,
            help: "The list to display reminders from. Uses the user's default list by default.")
    var list: String?

    @Flag(name: .shortAndLong,
          help: "Display todo items from all lists. If this flag is passed, the --list option is ignored.")
    var all: Bool = false

    @Flag(name: .shortAndLong,
          help: "Show only overdue reminders.")
    var overdue: Bool = false

    @Option(name: .shortAndLong,
            help: "Show only those reminders due before a given date. Accepts natural language input, e.g., 'next friday'")
    var before: String?

    @Option(name: .shortAndLong,
            help: "Show only reminders of this priority or higher.")
    var priority: String?

    @Option(name: .short,
            help: "The maximum number of reminders to show. Passing n < 1 prints all reminders.")
    var n: Int = 20

    func run() async throws {
        let store = try await getStore()

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: overdue || before != nil
                ? parseDate(before) // get everything due before now
                : nil,
            calendars: all
                ? store.calendars(for: .reminder)
                : [getCalendar(list, store: store)]
        )

        var done = false
        store.fetchReminders(matching: predicate) { reminders in

            var reminders = reminders ?? [EKReminder]() // make mutable, non-nill copy
            reminders.sort() // sort by due date

            // filter by priority
            if let priority {
                reminders = reminders.filter { r in
                    if let p = PRIORITIES[priority] { return (r.priority != 0) && (r.priority <= p) }
                    else { fatalError("Invalid priority: \(priority)") }
                }
            }

            // take the most pressing n reminders
            if n > 0 { reminders = Array(reminders.prefix(n)) }

            printReminders(reminders)
            done = true
        }

        // loop so the app doesn't quit before callbacks are done
        while !done {}
    }
}

func printReminders(_ reminders: [EKReminder]) {
    // print header
    print() // empty line to give space between prompt and printout
    print(BANNER.style.Bold.foreground.Cyan)
    print()
    print(String(repeating: HORIZONTAL_DIVIDER, count: WIDTH))
    print()

    // print reminders themselves
    for reminder in reminders {
        printReminder(reminder)
    }
}

func printReminder(_ reminder: EKReminder) {
    let padding = String(repeating: " ", count: WIDTH - reminder.title.count - 15)
    print("\(styleTitle(reminder)) \(padding) \(styleDate(reminder))")
}

func styleTitle(_ reminder: EKReminder) -> String {
    var styledTitle: String

    switch reminder.priority {
    case 9: // low
        styledTitle = reminder.title.style.Bold
    case 5: // med
        styledTitle = reminder.title.style.Bold.foreground.Yellow
    case 1: // high
        styledTitle = reminder.title.style.Bold.foreground.Red
    case _: // none
        styledTitle = reminder.title
    }

    return styledTitle
}

func styleDate(_ reminder: EKReminder) -> String {
    var styledDate: String
    if reminder.dueDateComponents == nil {
        styledDate = ""
    } else {
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        let date = Calendar.current.date(from: reminder.dueDateComponents!)!
        styledDate = "\(CALENDAR) \(dateFormatter.string(from: date))"

        let dueDay = Calendar.current.date(from: reminder.dueDateComponents!)
        if dueDay! == NOW { styledDate = styledDate.foreground.Yellow } // due today
        if dueDay! < NOW { styledDate = styledDate.foreground.Red } // overdue
    }

    return styledDate
}

func getStore() async throws -> EKEventStore {
    let store = EKEventStore()
    let givenAccess = try await store.requestAccess(to: .reminder)

    if !givenAccess {
        fatalError("User refused access to calendar database")
    }

    return store
}

func getCalendar(_ title: String?, store: EKEventStore) -> EKCalendar {
    return title == nil
        ? store.defaultCalendarForNewReminders()!
        : store.calendars(for: .reminder).filter { calendar in calendar.title == title }[0]
}

func parseDate(_ dateString: String?) -> Date {
    if let dateString {
        Chrono.preferredLanguage = .english
        return CHRONO.parseDate(text: dateString, opt: [.forwardDate: 1])!
    } else {
        return Date()
    }
}

// this lets us sort by due date
extension EKReminder: Comparable {
    public static func < (lhs: EKReminder, rhs: EKReminder) -> Bool {
        let calendar = Calendar.current

        // force reminders without due dates to show up at the bottom of the list
        var defaultComponents = DateComponents()
        defaultComponents.year = 3000

        return calendar.date(from: lhs.dueDateComponents ?? defaultComponents)!
            < calendar.date(from: rhs.dueDateComponents ?? defaultComponents)!
    }
}
