# todo.swift

I use Apple's reminders app religiously on my phone and laptop, but I've always
wanted a way to view and add to my to-do list without leaving the terminal. This
is my solution. Because `todo.swift` natively interfaces with Apple's reminders
database using the EventKit API, changes will be reflected in the Reminders app
across all your Apple devices. Currently, there is support for due dates, adding
notes, and setting the reminder priority.

PRs welcome.

## Screenshot

<img width="1193" alt="image" src="https://github.com/alipatti/todo.swift/assets/78563685/b62c2546-dfbb-4674-abe6-c32d6babe2fc">

## Installation

Using fish:

```fish
swift build # build project
ln -s (readlink -f .build/debug/todo) ~/.local/bin # link executable to path
```
