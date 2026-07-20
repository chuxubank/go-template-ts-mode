;;; go-template-ts-mode-treesit-fold.el --- Fold Go templates with treesit-fold -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka

;;; Commentary:

;; Optional `treesit-fold' integration for `go-template-ts-mode'.

;;; Code:

(require 'treesit)
(require 'treesit-fold)

(defun go-template-ts-mode-treesit-fold-range-action (node offset)
  "Return the fold range for Go-template action NODE using OFFSET."
  (let (begin end)
    (dotimes (index (treesit-node-child-count node))
      (let* ((child (treesit-node-child node index))
             (type (treesit-node-type child)))
        (when (and (not begin) (member type '("}}" "-}}")))
          (setq begin (treesit-node-end child)))
        (when (member type '("{{" "{{-"))
          (setq end (treesit-node-start child)))))
    (when (and begin end (<= begin end))
      (cons (+ begin (car offset)) (+ end (cdr offset))))))

(setf (alist-get 'go-template-ts-mode treesit-fold-range-alist)
      (mapcar
       (lambda (type)
         (cons type #'go-template-ts-mode-treesit-fold-range-action))
       '(if_action range_action with_action define_action block_action)))

(provide 'go-template-ts-mode-treesit-fold)
;;; go-template-ts-mode-treesit-fold.el ends here
