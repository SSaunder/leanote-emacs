;;; leanote.el --- Major mode for using leanote.  -*- lexical-binding: t; -*-

;; Copyright (C) 2016 Aborn Jiang

;; Author: Aborn Jiang <aborn.jiang@gmail.com>
;; Version: 0.1
;; Package-Requires: ((cl-lib "0.5") (request "0.2") (let-alist "1.0.3"))
;; Keywords: leanote, note, markdown
;; Homepage: https://github.com/aborn/leanote-mode
;; URL: https://github.com/aborn/leanote-mode

;; This file is NOT part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
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

;; emacs use leanote

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'request)
(require 'let-alist)

;;;;  Variables

;; for debug
(defvar leanote-debug-data nil)

;; user info
(defvar leanote-user nil)
(defvar leanote-user-password nil)
(defvar leanote-user-email nil)
(defvar leanote-user-id nil)
(defvar leanote-token nil)

;; local cache 
(defvar leanote-current-note-book nil)

;; api
(defvar leanote-api-login "/auth/login")
(defvar leanote-api-getnotebooks "/notebook/getNotebooks")
(defvar leanote-api-getnotecontent "/note/getNoteContent")
(defvar leanote-api-getnoteandcontent "/note/getNoteAndContent")
(defvar leanote-api-getnotes "/note/getNotes")

(defcustom leanote-api-root "https://leanote.com/api"
  "api root"
  :group 'leanote
  :type 'string)

(defcustom leanote-request-timeout 10
  "Timeout control for http request, in seconds."
  :group 'leanote
  :type 'number)

(defcustom leanote-local-root-path "~/leanote/note"
  "local leanote path"
  :group 'leanote
  :type 'string)

(defgroup leanote nil
  "leanote mini group"
  :prefix "leanote-"
  :group 'external)

(define-minor-mode leanote
  "leanot mini mode"
  :init-value nil
  :lighter " leanote"
  :keymap '(([C-c m] . leanote-init))
  :group 'leanote)

(defun leanote-init ()
  "init it"
  (interactive)
  (message "leanote start."))

(defun leanote-parser ()
  "parser"
  (json-read-from-string (decode-coding-string (buffer-string) 'utf-8)))

(defun leanote-get-note-content (noteid)
  "get note content, return type.Note"
  (interactive)
  (leanote-common-api-action "noteId" noteid leanote-api-getnotecontent))

(defun leanote-get-notes (notebookid)
  "get notebook notes list"
  (interactive)
  (leanote-common-api-action "notebookId" notebookid leanote-api-getnotes))

(defun leanote-get-note-and-content (noteid)
  "get note and content, return  type.Note"
  (interactive)
  (leanote-common-api-action "noteId" noteid leanote-api-getnoteandcontent))

(defun leanote-common-api-action (param-key param-value api)
  "common api only one parameter"
  (interactive)
  (let ((result nil))
    (request (concat leanote-api-root api)
             :params `(("token" . ,leanote-token) (,param-key . ,param-value))
             :sync t
             :parser 'leanote-parser
             :success (cl-function
                       (lambda (&key data &allow-other-keys)
                         (setq leanote-debug-data data)
                         (unless (eq (assoc-default 'Ok leanote-debug-data) :json-false)
                           (setq result data))
                         ))
             )
    result)
  )

(defun leanote-get-note-books ()
  "get note books"
  (interactive)
  (request (concat leanote-api-root leanote-api-getnotebooks)
           :params `(("token" . ,leanote-token))
           :sync t
           :parser 'leanote-parser
           :success (cl-function
                     (lambda (&key data &allow-other-keys)
                       (if (not (arrayp data))
                           (progn
                             (message "get-note-book failed, cause: %s"
                                      (assoc-default 'Msg data)))  ;; NOTLOGIN
                         (progn
                           (setq leanote-current-note-book data)
                           (leanote-mkdir-notebooks-directory-structure data)
                           (message "finished. notebook number=%d" (length data)))))))
  )

(defun leanote-mkdir-notebooks-directory-structure (note-books-data)
  "make note-books hierarchy"
  (unless (file-exists-p leanote-local-root-path)
    (message "make root dir %s" leanote-local-root-path)
    (make-directory leanote-local-root-path t))
  (cl-loop for elt in (append note-books-data nil)
           collect
           (let* ((title (assoc-default 'Title elt))
                  (has-parent (not (string= "" (assoc-default 'ParentNotebookId elt))))
                  (current-note-book (expand-file-name title leanote-local-root-path)))
             (message "title=%s" title)
             (when (and (not has-parent) (not (file-exists-p current-note-book)))
               (make-directory current-note-book)
               ))
           ))

(defun leanote-login (&optional user password)
  "login in leanote"
  (interactive)
  (when (null user)
    (setq user (read-string "Email: " nil nil leanote-user-email)))
  (when (null password)
    (setq password (read-passwd "Password: " nil leanote-user-password)))
  (request (concat leanote-api-root leanote-api-login)
           :params `(("email" . ,user)
                     ("pwd" . ,password))
           :sync t
           :parser 'leanote-parser
           :success (cl-function
                     (lambda (&key data &allow-other-keys)
                       (if (equal :json-false (assoc-default 'Ok data))
                           (message "%s" (assoc-default 'Msg data))
                         (progn
                           (setq leanote-token (assoc-default 'Token data))
                           (setq leanote-user (assoc-default 'Username data))
                           (setq leanote-user-email (assoc-default 'Email data))
                           (setq leanote-user-id (assoc-default 'UserId data))
                           (setq leanote-user-password password) ;; update password
                           (message "login success!")))))))

(provide 'leanote)
