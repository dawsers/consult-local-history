# consult-local-history

## Introduction

This package is based on [antham's](https://github.com/antham)
[helm-backup](https://github.com/antham/helm-backup), and uses his
[git-backup](https://github.com/antham/git-backup) library.

*consult-local-history* provides a similar interface to *helm-backup* to manage
a local file history using a `git` repository, but using
[consult](https://github.com/minad/consult) and
[embark](https://github.com/oantolin/embark) as the front end.

*consult-local-history* can be downloaded
[here](https://github.com/dawsers/consult-local-history).


## Requirements

The package requires `git`, `git-backup`, `consult` and `embark`.


## Features

* Every time a file is saved, it is automatically committed to the local history
  repository.

* To add a more descriptive commit message for certain states, save manually
  using `consult-local-history-named-save-file`

* Use `consult-local-history` to view the available backups for the current
  buffer file. It will show the date, commit message and a preview of the
  changes introduced with each backup.

* Use *embark* actions from within `consult-local-history`. There are three
  supported actions:

  1. `<RET>`: default, opens the selected backup in a new buffer.
  2. `"e"`: ediff between the selected backup and the current buffer.
  3. `"r"`: revert current buffer to the state of the selected backup.

* Use `consult-local-history-delete-file` to remove a file from the local
  history repository.


## Installation

Using `straight.el`:

```emacs-lisp
;; required
(use-package git-backup
  :straight t
)

(use-package consult-local-history
  :straight (consult-local-history
             :host github
             :repo "dawsers/consult-local-history"
  )
)
```

## Customization

There are several variables that can be customized. Their default value between
`()`:


* `consult-local-history-path` (`"~/.emacs-backups/consult-local-history"`):
  Storage path for local history repository.

* `consult-local-history-git-binary` (`"git"`): `git` binary to use.

* `consult-local-history-list-format` (`"%cd, %ar"`): Format for the backup time
  displayed.

* `consult-local-history-excluded-entries` (`nil`): List of file/folder regexp
  to exclude from local history.


## Commands

* `consult-local-history`: View and manage the available backups in the local
  history repository for the current buffer file. As described above, there are
  three possible actions for the selected candidate, using embark.

  1. `<RET>`: default, opens the selected backup in a new buffer.
  2. `"e"`: ediff between the selected backup and the current buffer.
  3. `"r"`: revert current buffer to the state of the selected backup.

  The preview buffer shows the changes introduced with the currently selected
  backup.

* `consult-local-history-delete-file`: Removes a file from the local history
  repository.

* `consult-local-history-named-save-file`: Saves the current buffer and adds a
  custom commit message for the local history backup. Use it for important saves.


## Key Bindings

None for the interactive commands, so you can select your own. The embark
actions have a map with the bindings described above.
