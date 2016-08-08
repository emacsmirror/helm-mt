;;; helm-mt.el --- helm multi-term management -*- lexical-binding: t -*-

;; Copyright (C) 2015, 2016 Didier Deshommes <dfdeshom@gmail.com>

;; Author: Didier Deshommes <dfdeshom@gmail.com>
;; URL: https://github.com/dfdeshom/helm-mt
;; Version: 0.9
;; Package-Requires: ((emacs "24") (helm "0.0") (multi-term "0.0") (cl-lib "0.5"))
;; Keywords: helm multi-term

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

;; Helm bindings for managing `multi-term' terminals as well as
;; shells.  A call to `helm-mt` will show a list of terminal sessions
;; managed by `multi-term` as well as buffers with major mode
;; `shell-mode`.  From there, you are able to create, delete or switch
;; over to existing terminal buffers.

;;; Code:

(require 'cl-lib)
(require 'helm)
(require 'helm-lib)
(require 'helm-source)
(require 'multi-term)

(defvar helm-mt/keymap
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map helm-map)
    (define-key map (kbd "M-D") 'helm-mt/helm-buffer-run-delete-terminals)
    (delq nil map))
  "Keymap for `helm-mt'.")

(defun helm-mt/terminal-buffers ()
  "Filter for buffers that are terminals only.
Includes buffers managed by `multi-term' (excludes dedicated term
buffers) and buffers in `shell-mode'."
  (cl-loop for buf in (buffer-list)
           if (or (member buf multi-term-buffer-list)
                  (eq (buffer-local-value 'major-mode buf) 'shell-mode))
           collect (buffer-name buf)))

(defun helm-mt/launch-terminal (name prefix mode)
  "Launch a terminal in a new buffer.
NAME is the desired name of the buffer, which will be prefixed with
mode and made unique.  PREFIX is passed on to the function that
creates the terminal as a prefix argument.  MODE is either 'term or
'shell."
  (setq current-prefix-arg prefix)
  (cl-case mode
    ('term
     (setq name-prefix "terminal")
     (call-interactively 'multi-term))
    ('shell
     (setq name-prefix "shell")
     (call-interactively 'shell)))
  (rename-buffer (generate-new-buffer-name (format "*%s<%s>*" name-prefix name))))

(defun helm-mt/delete-marked-terminals (ignored)
  "Delete marked terminals.
Argument IGNORED is not used."
  (let* ((bufs (helm-marked-candidates))
         (killed-bufs (cl-count-if 'helm-mt/delete-terminal bufs)))
    (with-helm-buffer
      (setq helm-marked-candidates nil
            helm-visible-mark-overlays nil))
    (message "Deleted %s terminal(s)" killed-bufs)))

(defun helm-mt/delete-terminal (name)
  "Delete terminal NAME."
  (if (get-buffer-process name)
      (delete-process name))
  (kill-buffer name))

(defun helm-mt/helm-buffer-run-delete-terminals ()
  "Run 'delete marked terminals' action from `helm-mt' source list."
  (interactive)
  (with-helm-alive-p
    (helm-exit-and-execute-action 'helm-mt/delete-marked-terminals)))
(put 'helm-mt/helm-buffer-run-delete-terminals 'helm-only t)

(defun helm-mt/source-terminals ()
  "Helm source with candidates for all terminal buffers."
  (helm-build-sync-source
      "Terminals"
    :candidates (lambda () (or
                            (helm-mt/terminal-buffers)
                            (list "")))
    :action (helm-make-actions
             "Switch to terminal"
             (lambda (candidate)
               (switch-to-buffer candidate))
             "Delete marked terminal(s) `M-D'"
             (lambda (ignored)
               (helm-mt/delete-marked-terminals ignored)))))

(defun helm-mt/source-terminal-not-found (prefix)
  "Helm source to launch a new terminal.
PREFIX is passed on to `helm-mt/launch-terminal'.  Defaults to a
terminal with a unique name derived from the `default-directory'."
  (let ((default-display "Named after current directory (default)")
        (default-real (generate-new-buffer-name (expand-file-name default-directory))))
    (helm-build-sync-source
        "Launch a new terminal"
      :candidates '("dummy")
      :filtered-candidate-transformer (lambda (candidates _source)
                                        (if (string-equal helm-pattern "")
                                            (list `(,default-display . ,default-real))
                                          (list helm-pattern)))
      :matchplugin nil
      :match 'identity
      :volatile t
      :action (apply 'helm-make-actions
                     (apply 'append
                            (mapcar (lambda (mode)
                                      (list (format "Launch new %s" mode)
                                            `(lambda (candidate)
                                               (if (string-equal candidate ,default-display)
                                                   (setq candidate ,default-real))
                                               (helm-mt/launch-terminal candidate ,prefix (quote ,mode)))))
                                    (list 'term 'shell)))))))

;;;###autoload
(defun helm-mt (prefix)
  "Custom helm buffer for terminals only.
PREFIX is passed on to `helm-mt/term-source-terminal-not-found'."
  (interactive "P")
  (helm :sources `(,(helm-mt/source-terminals)
                   ,(helm-mt/source-terminal-not-found prefix))
        :keymap helm-mt/keymap
        :buffer "*helm mt*"))

(provide 'helm-mt)
;;; helm-mt.el ends here
