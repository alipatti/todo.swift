# todo.swift

I use Apple's reminders app religiously on my phone and laptop, and have always
wanted a way to view and add to my to-do list without leaving the terminal. This
is my solution. Because `todo.swift` interfaces directly with Apple's reminders
database using the EventKit API, changes will be reflected in the Reminders app
across all your Apple devices.

PRs welcome.

<!-- TODO: add screenshot -->

## Installation

Using fish:

```fish
swift build # build project
ln -s (readlink -f .build/debug/todo) ~/.local/bin # link executable to path
```
