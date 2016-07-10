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
(defvar leanote-user nil)
(defvar leanote-user-password nil)
(defvar leanote-user-email nil)
(defvar leanote-user-id nil)
(defvar leanote-token nil)
(defvar leanote-api-login "/auth/login")
(defvar leanote-api-getnotebooks "/notebook/getNotebooks")
(defvar leanote-debug-data nil)

(defcustom leanote-api-root "https://leanote.com/api"
  "api root"
  :group 'leanote
  :type 'string)

(defcustom leanote-request-timeout 10
  "Timeout control for http request, in seconds."
  :group 'leanote
  :type 'number)

(defcustom leanote-local-path "~/leanote/note"
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
                           (setq leanote-debug-data data)
                           (message "finished. notebook number=%d" (length data)))))))
  )

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
