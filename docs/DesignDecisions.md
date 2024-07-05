# Design Decisions

This document records the key design decisions made during the development of the MOLD PowerShell module. It outlines the rationale behind choices related to the templating engine, file structure, parameterization, and other architectural aspects. The goal is to provide transparency into the thought process behind MOLD's design, facilitate future development, and aid in understanding the trade-offs involved in various choices.

## Why reinvent wheel?

- Existing modules like Plaster : Unmanged, xml files, doesnt support PS7
- [Dotnet Templating](https://github.com/dotnet/templating) : Very promising project, but it currently lacks full (any?) support for PowerShell. Additionally, it introduces a DLL dependency and relies on a project that is primarily focused on C#/F#, which may not be ideal for plain text templating.

## Placeholders

> Template engines that do not employ placeholders or tokenization for substitution are not possible, atleast as  universal solutions compatible with any programming language.

MOLD utilizes a simple <% MOLD_TYPE_Variable %>,

- Heavily inspired by `plaster`
- `<% %>` is unique enough and not used in many languages

## JSON Schema

This solution is developed from scratch to meet specific requirements. It is designed as an array that can be easily converted into a PowerShell hashtable for convenient consumption and manipulation.

## Local Templates and Templates repository

1. PSData extension in psd1: This follows same logic as Plaster and makes it easy for other PowerShell module to ship templates with module
2. Local Folder : You can directly point at local template folder to choose local template
3. Auto Scan Directory : This is if you want to save certain local path as local template source and call them by ShortNames. MOLD will look for "MOLD_TEMPLATES" env variable which can store ";" separated directories with templates.
Eg MOLD_TEMPLATES content `/Some/Path;/SomeOther/Path` just like `PATH` environment variable

## File Operations and Complex Logic

MOLD does not handle file renaming, command execution, or complex directory/file arrangements. It is a command-line tool designed to prompt users for input, copy pre-defined content, and perform variable substitution.

In essence, MOLD's primary function is to gather user responses to a set of questions. The subsequent actions taken with these responses are entirely up to the user. Advanced logic and custom functionalities can be implemented within the MOLD_SCRIPT.ps1 script, which is invoked as part of the Invoke-Mold command. This approach provides users with a high degree of flexibility and customization.

## Constraints and Mitigation Strategies

### Identifying Text Files
A significant challenge lies in the accurate identification of text-only files. There is no definitive criterion to determine what constitutes plain text. Despite extensive research, a reliable method remains elusive.

### Mitigation
To prevent unintended substitution within non-text files such as MP4s (which to my surprise can be openned in Notepad - it wont play though), module incorporates a size-based filter, excluding files larger than 1MB. This threshold is based on the assumption that most plain text files will be smaller than this limit, thereby reducing the likelihood of unintended modifications of large files. If by chance you have a text file larger than 1mb, you shouldn't be updating content using templating anyway (use MOLD_SCRIPT.ps1 to build custom logic)
