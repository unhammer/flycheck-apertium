;;; flycheck-apertium.el --- Apertium checkers in flycheck

;; Copyright (C) 2016 Kevin Brubeck Unhammer <unhammer+apertium@mm.st>
;;
;; Author: Kevin Brubeck Unhammer <unhammer+apertium@mm.st>
;; Created: 23 March 2016
;; URL: http://wiki.apertium.org/wiki/Emacs
;; Version: 0.2
;; Keywords: convenience, tools, xml
;; Package-Requires: ((flycheck "0.25"))

;;; Commentary:

;; This package adds support for some Apertium source formats to
;; flycheck.

;; For best results, get the core Apertium development tools
;; (apertium-all-dev) from the nightly repos:
;; http://wiki.apertium.org/wiki/Installation

;; To use it, add this to your init.el:

;; (when (locate-library "flycheck-apertium")
;;   (require 'flycheck-apertium)
;;   (add-hook 'nxml-mode-hook 'flycheck-mode))

;; If not installing through ELPA, you'll also have to do

;; (add-to-list 'load-path "/path/to/flycheck-apertium-directory/")

;;; License:

;; This file is not part of GNU Emacs.
;; However, it is distributed under the same license.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Code:
(require 'flycheck)

(defun flycheck-apertium-file-transferp ()
  "Non-nil iff the current buffer is an Apertium transfer rule file."
  (and (buffer-file-name)
       (string-match "\\.t[0-9s]x$" buffer-file-name)))

(flycheck-define-checker apertium-transfervm
  "An Apertium transfer rule checker using the vm-for-transfer compiler.

See URL `https://github.com/ggm/vm-for-transfer-cpp'."
  :command ("apertium-compile-transfer" "-i" source "-o" null-device)
  :error-patterns
  ((error line-start
          (file-name)
          ":"
          line
          ": "
          (id (one-or-more (not (any ":"))))
          ": "
          (message (one-or-more not-newline))
          line-end)
   (error line-start "Error: line "
          ;; TODO: line number has hard spaces unless LC_ALL=C;
          ;; abusing id to turn it into line in error-filter:
          (id (one-or-more (not (any ","))))
          ", "
          (message (one-or-more not-newline))
          line-end))
  :error-filter
  (lambda (errors)
    (dolist (err errors)
      (let ((line (string-to-number
                   (replace-regexp-in-string "[^0-9]+"
                                             ""
                                             (flycheck-error-id err)))))
        (when (> line 0)
          (setf (flycheck-error-line err) line))))
    errors)
  ;; TODO: line number is at the end of the rule element, not very accurate!
  :predicate flycheck-apertium-file-transferp
  :modes (xml-mode nxml-mode))

(add-to-list 'flycheck-checkers 'apertium-transfervm)

(defun flycheck-apertium-dix-xsd ()
  "Find the dix.xsd from within this flycheck-apertium package."
  (let ((source-dir (file-name-directory (find-lisp-object-file-name
                                          #'flycheck-apertium-file-transferp
                                          nil))))
    (concat source-dir "dix.xsd")))

(flycheck-define-checker apertium-dix
  "Check using the dix.xsd from apertium-validate-dictionary."
  :command ("xmllint"  "--schema" (eval (flycheck-apertium-dix-xsd)) "--noout" "-")
  :standard-input t
  :error-patterns
  ((error line-start "-:" line ": " (message) line-end))
  :predicate (lambda ()
               (and (buffer-file-name)
                    (string-match "\\.dix$" buffer-file-name)))
  :error-filter
  (lambda (errors)
    (dolist (err errors)
      ;; Remove some redundant info from the message:
      (let ((msg (replace-regexp-in-string "element \\([^:]*\\): Schemas validity error : Element '\\1'"
                                           "Element \\1"
                                           (flycheck-error-message err))))
        (setf (flycheck-error-message err) msg)))
    errors)
  :modes (xml-mode nxml-mode))

(add-to-list 'flycheck-checkers 'apertium-dix)

(defun flycheck-apertium-dix-overrides-xmllint ()
  "If the `apertium-dix' checker is available, turn off plain xmllint.
The `apertium-dix' checker uses xmllint anyway, but with the
correct schema."
  (when (flycheck-may-use-checker 'apertium-dix)
    (flycheck-disable-checker 'xml-xmllint)))

(add-hook 'flycheck-mode-hook #'flycheck-apertium-dix-overrides-xmllint)

(provide 'flycheck-apertium)
;;; flycheck-apertium.el ends here
