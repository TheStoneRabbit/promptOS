# Upcoming Changes

- Improve the graphical interface for promptsh to make it easier and more understandable for non-technical users to interact with.
- Add support for using custom skills in promptos.
- Make the AI automatically search for files if a given path cannot be found, and suggest likely matches to the user.
- Ensure commands execute without user interaction whenever safe and appropriate (e.g., use --noconfirm with pacman install to bypass [Y/n] prompts).
- When launching graphical applications, use the & operator or disown the process so the user can return to promptsh, or otherwise ensure promptOS remains accessible after opening a window.
- Remember autorun preference across sessions and after reboot
