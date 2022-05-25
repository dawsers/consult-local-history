;;; consult-local-history.el --- Local history of files using git -*- lexical-binding: t -*-

;; Copyright (C) 2022 dawsers

;; Author: dawsers <dawser@gmx.com>
;; URL: http://github.com/dawsers/consult-local-history
;; Version: 1.0
;; Package-Requires: ((git-backup "0.0.1") (consult "0.17") (embark "0.17"))
;; Keywords: local-history, backup, convenience, files, tools, vc

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; To explore the current buffer's local history call `consult-local-history':
;; M-x consult-local-history
;; Browsing the history, shows the changes introduced by each version in the
;; preview buffer.
;; There are two embark actions available:
;;  "e" - show ediff of current buffer with selected version
;;  "r" - revert current buffer to selected version
;; Selecting a candidate opens it in a new buffer.

;; To remove all backups from any file in the local history repository, call
;; `consult-local-history-delete-file':
;; M-x consult-local-history-delete-file

;; To save a file with a custom commit message, call
;; 'consult-local-history-named-save-file'
;; M-x consult-local-history-named-save-file

;;; Code:

;; git-backup is required from package load, so the save hook works
(require 'git-backup)

(defgroup consult-local-history nil
  "Local history system using git and consult."
  :group 'consult)

(defcustom consult-local-history-path "~/.emacs-backups/consult-local-history/"
  "Local history location."
  :group 'consult-local-history
  :set (lambda (symbol path) (set-default symbol (expand-file-name path)))
  :type 'string)

(defcustom consult-local-history-git-binary "git"
  "Git binary path."
  :group 'consult-local-history
  :type 'string)

(defcustom consult-local-history-list-format "%cd, %ar"
  "Format used to display entries in consult buffer, follow git log format."
  :group 'consult-local-history
  :type 'string)

(defcustom consult-local-history-excluded-entries nil
  "Define a list of file/folder regexp to exclude from local history.
/home/user/password => exclude password in /home/user
.*\\.el$ => exclude .el extension
/root/.* => exclude everything inside root
.*/password/.* => exclude all folders with name 'password'"
  :group 'consult-local-history
  :type '(repeat regexp))


(defvar consult-local-history-history nil
  "History for `consult-local-history'.")

(defvar consult-local-history--buffer-name "*consult-local-history*"
  "Name of the preview buffer.")


(defun consult-local-history--show-diff (commit-id buffer)
  "Show differences introduced with version COMMIT-ID in the requested BUFFER."
  (let ((buf (get-buffer-create buffer)))
    (with-current-buffer buf
      (diff-mode)
      (insert (git-backup--exec-git-command consult-local-history-git-binary consult-local-history-path (list
                                            "show" "--pretty=format:%H"
                                            commit-id) t))
      (display-buffer buf)
    )
  )
)

(defun consult-local-history--candidate-id (candidate)
  "Get the commit-id for CANDIDATE."
  (get-text-property 0 'commit-id candidate)
)

(defun consult-local-history--preview (action candidate)
  "Preview CANDIDATE when ACTION is 'preview."
  (cond ((or (not candidate) (eq action 'exit))
         (when (get-buffer consult-local-history--buffer-name)
           (kill-buffer consult-local-history--buffer-name)))
        ((eq action 'preview)
         (when-let ((id candidate))
           (when (get-buffer consult-local-history--buffer-name)
             (kill-buffer consult-local-history--buffer-name))
           (consult-local-history--show-diff id consult-local-history--buffer-name)))
))

(defun consult-local-history--generate-candidate (time id msg)
  "Generate a candidate with TIME and MSG, adding the commit ID as a text property."
   (propertize (concat (format "%-55s" time) msg) 'commit-id id)
)

;; Overload git-backup candidate generator
(defun git-backup-list-file-change-time (git-binary-path backup-path git-output-format filename)
  "Build list with time, commit id and commit message FILENAME.  GIT-BINARY-PATH is the absolute path where git stands, BACKUP-PATH is the path where backups are stored, GIT-OUTPUT-FORMAT follows format used by git in log command."
  (let ((filename-for-git (git-backup--transform-filename-for-git filename)))
    (when (and filename
               (string= (s-chop-suffixes '("\0") (git-backup--exec-git-command git-binary-path backup-path (list "ls-files" "-z" filename-for-git) t))
                        filename-for-git) t)
      (cl-mapcar #'consult-local-history--generate-candidate
                 (split-string (git-backup--exec-git-command git-binary-path backup-path (list "log" (format
                                                                                                      "--pretty=format:%s"
                                                                                                      git-output-format)
                                                                                               filename-for-git) t) "\n")
                 (split-string (git-backup--exec-git-command git-binary-path backup-path (list "log" "--pretty=format:%H"
                                                                                               filename-for-git) t) "\n")
                 (split-string (git-backup--exec-git-command git-binary-path backup-path (list "log" "--pretty=format:%s"
                                                                                               filename-for-git) t) "\n")
                 ))))

(defun consult-local-history--get-candidates ()
  "Source candidates for 'consult-local-history'."
  (git-backup-list-file-change-time consult-local-history-git-binary consult-local-history-path consult-local-history-list-format (buffer-file-name))
)

;; Preview helper for consult-local-history-delete-file
(defun consult-local-history--show-file (filename buffer)
  "Show last commit of FILENAME in the requested BUFFER."
  (let ((buf (get-buffer-create buffer)))
    (with-current-buffer buf
      (insert (git-backup--exec-git-command consult-local-history-git-binary consult-local-history-path (list
                                            "show" (format "HEAD:%s" filename)) t))
      (display-buffer buf)
    )
  )
)

;; State function to preview consult-local-history-delete-file candidates
(defun consult-local-history--preview-file (action candidate)
  "Preview CANDIDATE when ACTION is 'preview."
  (cond ((or (not candidate) (eq action 'exit))
         (when (get-buffer consult-local-history--buffer-name)
           (kill-buffer consult-local-history--buffer-name)))
        ((eq action 'preview)
         (when (get-buffer consult-local-history--buffer-name)
           (kill-buffer consult-local-history--buffer-name))
         (consult-local-history--show-file candidate consult-local-history--buffer-name))))

(defun consult-local-history--get-files ()
  "Source candidates for 'consult-local-history-delete-file'."
  (string-lines (git-backup--exec-git-command consult-local-history-git-binary consult-local-history-path
       (list "ls-tree" "--full-tree" "-r" "--name-only" "HEAD") t))
)

;;;###autoload
(defun consult-local-history-save-file ()
  "Create a new version of the current buffer's associated file."
  (git-backup-version-file consult-local-history-git-binary consult-local-history-path consult-local-history-excluded-entries (buffer-file-name)))

;;;###autoload
(defun consult-local-history-named-save-file (msg)
  "Create a new version of the current buffer's associated file with commit MSG."
  (interactive "sCommit Message: ")
  (save-buffer)  ;this will call consult-local-history-save-file
  ;; amend the commit message
  (git-backup--exec-git-command consult-local-history-git-binary consult-local-history-path
                                (list "commit" "--amend" "-m" msg)))


;;;###autoload
(defun consult-local-history ()
  "Review and act on current buffer's local history."
  (interactive)
  (require 'consult)
  (require 'embark)
  (let ((selected (consult--read (consult-local-history--get-candidates)
            :prompt "Backup: "
            :require-match t
            :sort nil
            :lookup (apply-partially #'consult--lookup-prop 'commit-id)
            :category 'consult-local-history-entry
            :state #'consult-local-history--preview
            :history '(:input consult-local-history-history)
       )))
    (git-backup-open-in-new-buffer consult-local-history-git-binary consult-local-history-path selected (buffer-file-name))
  )
)

;;;###autoload
(defun consult-local-history-delete-file ()
  "Delete a file from the `consult-local-history` repository."
  (interactive)
  (require 'consult)
  (git-backup-remove-file-backups consult-local-history-git-binary consult-local-history-path
    (consult--read (consult-local-history--get-files)
              :prompt "Backup file: "
              :require-match t
              :sort nil
              :category 'file
              :state #'consult-local-history--preview-file
    )
  )
)

;; Embark integration
(defun consult-local-history-ediff (msg)
  "Ediff commit id in MSG with current buffer."
  (let ((commit-id (consult-local-history--candidate-id msg)))
    (git-backup-create-ediff consult-local-history-git-binary consult-local-history-path commit-id (current-buffer))
  )
)

(defun consult-local-history-revert (msg)
  "Revert current buffer to state in commit id in MSG."
  (let ((commit-id (consult-local-history--candidate-id msg)))
    (git-backup-replace-current-buffer consult-local-history-git-binary consult-local-history-path commit-id (buffer-file-name))
  )
)

(defvar consult-local-history-map
    (let ((map (make-sparse-keymap)))
      (define-key map (kbd "e") 'consult-local-history-ediff)
      (define-key map (kbd "r") 'consult-local-history-revert)
      map)
    "Keymap for actions on consult-local-history entries.")

(eval-after-load "embark"
  '(progn
      (set-keymap-parent consult-local-history-map embark-general-map)
      (add-to-list 'embark-keymap-alist '(consult-local-history-entry . consult-local-history-map))
      (add-to-list 'embark-pre-action-hooks '(consult-local-history-revert embark--confirm))
   )
)

;; Add file to repository after each save
(add-hook 'after-save-hook 'consult-local-history-save-file)

;; Optimize repository at startup
(eval-after-load "consult-local-history"
  '(progn
     (git-backup-clean-repository consult-local-history-git-binary consult-local-history-path)))

(provide 'consult-local-history)

;; Local Variables:
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:

;;; consult-local-history.el ends here
