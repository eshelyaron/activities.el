;;; activities-tabs.el --- Integrate activities with tabs  -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Free Software Foundation, Inc.

;; Author: Adam Porter <adam@alphapapa.net>
;; Keywords: convenience
;; Version: 0.1-pre
;; Package-Requires: ((emacs "29.1"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This library integrates activities with `tab-bar-mode' tabs.

;;; Code:

;;;; Requirements

(require 'activities)

(require 'tab-bar)

;;;; Customization

(defgroup activities-tabs nil
  "Integrates activities and tabs."
  :group 'activities)

(defcustom activities-tabs-before-resume-functions nil
  "Functions called before resuming an activity.
Each is called with one argument, the activity."
  :type 'hook)

(defcustom activities-tabs-prefix "α:"
  "Prepended to activity names in tabs."
  :type 'string)

;;;; Mode

;;;###autoload
(define-minor-mode activities-tabs-mode
  "Integrate Activities with `tab-bar-mode'.
When active, activities are opened in new tabs and named
accordingly."
  :global t
  :group 'activities
  (let ((override-map '((activities-activity-active-p . activities-tabs-activity-active-p)
                        (activities--set . activities-tabs-activity--set)
                        (activities--switch . activities-tabs--switch)
                        (activities-current . activities-tabs-current)
                        (activities-close . activities-tabs-close))))
    (if activities-tabs-mode
        (progn
          (tab-bar-mode 1)
          (advice-add #'activities-resume :before #'activities-tabs-before-resume)
          (pcase-dolist (`(,symbol . ,function) override-map)
            (advice-add symbol :override function)))
      (advice-remove #'activities-resume #'activities-tabs-before-resume)
      (pcase-dolist (`(,symbol . ,function) override-map)
        (advice-remove symbol function)))))

;;;; Functions

(cl-defun activities-tabs-close (activity)
  "Close ACTIVITY.
Its state is not saved, and its frames, windows, and tabs are
closed."
  (activities--switch activity)
  (tab-bar-close-tab))

(defun activities-tabs--switch (activity)
  "Switch to ACTIVITY.
Selects its tab, making one if needed.  Its state is not changed."
  (if-let ((tab (activities-tabs--tab activity)))
      (tab-bar-switch-to-tab (alist-get 'name tab))
    (tab-bar-new-tab))
  (tab-bar-rename-tab (activities-name-for activity)))

(defun activities-tabs--tab (activity)
  "Return ACTIVITY's tab."
  (pcase-let (((cl-struct activities-activity name) activity))
    (cl-find-if (lambda (tab)
                  (when-let ((tab-activity (alist-get 'activity (cdr tab))))
                    (equal name (activities-activity-name tab-activity))))
                (funcall tab-bar-tabs-function))))

(defun activities-tabs-current ()
  "Return current activity."
  (activities-tabs--tab-parameter 'activity (tab-bar--current-tab-find)))

(defun activities-tabs--tab-parameter (parameter tab)
  "Return TAB's PARAMETER."
  ;; TODO: Make this a gv.
  (alist-get parameter (cdr tab)))

(defun activities-tabs-activity--set (activity)
  "Set the current activity.
Sets the current tab's `activity' parameter to ACTIVITY."
  (let ((tab (tab-bar--current-tab-find)))
    (setf (alist-get 'activity (cdr tab)) activity)))

(defun activities-tabs-activity-active-p (activity)
  "Return non-nil if ACTIVITY is active.
That is, if any tabs have an `activity' parameter whose
activity's name is NAME."
  (activities-tabs--tab activity))

(defun activities-tabs-before-resume (activity &rest _)
  "Called before resuming ACTIVITY."
  (run-hook-with-args 'activities-tabs-before-resume-functions activity))

;; (defun activity-tabs-switch-to-tab (activity)
;;   "Switch to a tab for ACTIVITY."
;;   (pcase-let* (((cl-struct activity name) activity)
;;                (tab (cl-find-if (lambda (tab)
;;                                   (when-let ((tab-activity (alist-get 'activity tab)))
;;                                     (equal name (activity-name tab-activity))))
;;                                 (funcall tab-bar-tabs-function))) 
;;                (tab-name (if tab
;;                              (alist-get 'name tab)
;;                            (concat activity-tabs-prefix
;;                                    (string-remove-prefix activity-bookmark-prefix name)))))
;;     (tab-bar-switch-to-tab tab-name)))

;;;; Footer

(provide 'activities-tabs)

;;; activities-tabs.el ends here