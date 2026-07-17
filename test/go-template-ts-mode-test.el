;;; go-template-ts-mode-test.el --- Tests for go-template-ts-mode -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'go-template-ts-mode)

(ert-deftest go-template-ts-mode-registers-grammar-source ()
  (should (equal (alist-get 'gotmpl treesit-language-source-alist)
                 go-template-ts-mode-grammar-source))
  (cl-letf (((symbol-function 'treesit-install-language-grammar)
             (lambda (language) language)))
    (should (eq (go-template-ts-mode-install-grammar) 'gotmpl))))

(ert-deftest go-template-ts-mode-activates-without-installed-grammar ()
  (with-temp-buffer
    (cl-letf (((symbol-function 'treesit-ready-p) (lambda (&rest _) nil)))
      (go-template-ts-mode))
    (should (eq major-mode 'go-template-ts-mode))
    (should (equal comment-start "{{/* "))))

(ert-deftest go-template-ts-mode-parses-template ()
  (skip-unless (treesit-ready-p 'gotmpl))
  (with-temp-buffer
    (insert "{{ define \"card\" }}\n{{ if .Title }}{{ .Title }}{{ end }}\n{{ end }}")
    (go-template-ts-mode)
    (should (treesit-parser-list))
    (should (equal (treesit-node-type (treesit-buffer-root-node 'gotmpl))
                   "template"))
    (should-not
     (treesit-search-subtree (treesit-buffer-root-node 'gotmpl) "ERROR"))))

(ert-deftest go-template-ts-mode-finds-template-name ()
  (skip-unless (treesit-ready-p 'gotmpl))
  (with-temp-buffer
    (insert "{{ define `card` }}content{{ end }}")
    (go-template-ts-mode)
    (let ((node (treesit-search-subtree
                 (treesit-buffer-root-node 'gotmpl) "define_action")))
      (should (equal (go-template-ts-mode--defun-name node) "card")))))

(ert-deftest go-template-ts-mode-indents-nested-actions ()
  (skip-unless (treesit-ready-p 'gotmpl))
  (with-temp-buffer
    (insert "{{ define \"card\" }}\n{{ if .Title }}\n{{ .Title }}\n{{ else }}\nnone\n{{ end }}\n{{ end }}")
    (go-template-ts-mode)
    (indent-region (point-min) (point-max))
    (should
     (equal (buffer-string)
            "{{ define \"card\" }}\n  {{ if .Title }}\n    {{ .Title }}\n  {{ else }}\n    none\n  {{ end }}\n{{ end }}"))))

(provide 'go-template-ts-mode-test)
;;; go-template-ts-mode-test.el ends here
