;;; go-template-ts-mode-test.el --- Tests for go-template-ts-mode -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'go-template-ts-mode)
(eval-and-compile
  (defvar treesit-fold-range-alist nil))
(require 'go-template-ts-mode-treesit-fold)

(ert-deftest go-template-ts-mode-registers-template-file-patterns ()
  (let ((pattern (car (rassq 'go-template-ts-mode auto-mode-alist))))
    (should (string-match-p pattern "template.gotmpl"))
    (should (string-match-p pattern "template.tmpl"))))

(ert-deftest go-template-ts-mode-registers-grammar-source ()
  (should
   (equal go-template-ts-mode-grammar-source
          '("https://github.com/ngalaiko/tree-sitter-go-template"
            "master")))
  (should (equal (alist-get 'gotmpl treesit-language-source-alist)
                 go-template-ts-mode-grammar-source))
  (cl-letf (((symbol-function 'treesit-install-language-grammar)
             (lambda (language) language)))
    (should (eq (go-template-ts-mode-install-grammar) 'gotmpl))))

(ert-deftest go-template-ts-mode-customizes-grammar-source-for-installation ()
  (let ((original-source go-template-ts-mode-grammar-source)
        (custom-source '("https://example.invalid/tree-sitter-go-template"
                         "verified-revision"))
        installed-source)
    (unwind-protect
        (progn
          (setopt go-template-ts-mode-grammar-source custom-source)
          (cl-letf (((symbol-function 'treesit-install-language-grammar)
                     (lambda (language &rest _)
                       (setq installed-source
                             (alist-get language
                                        treesit-language-source-alist)))))
            (go-template-ts-mode-install-grammar))
          (should (equal installed-source custom-source)))
      (setopt go-template-ts-mode-grammar-source original-source))))

(ert-deftest go-template-ts-mode-installs-grammar-source-set-with-setq ()
  (let ((original-source go-template-ts-mode-grammar-source)
        (original-registered-source
         (alist-get 'gotmpl treesit-language-source-alist))
        (custom-source '("https://example.invalid/tree-sitter-go-template"
                         "setq-revision"))
        installed-source)
    (unwind-protect
        (progn
          (setq go-template-ts-mode-grammar-source custom-source)
          (cl-letf (((symbol-function 'treesit-install-language-grammar)
                     (lambda (language &rest _)
                       (setq installed-source
                             (alist-get language
                                        treesit-language-source-alist)))))
            (go-template-ts-mode-install-grammar))
          (should (equal installed-source custom-source)))
      (setq go-template-ts-mode-grammar-source original-source)
      (setf (alist-get 'gotmpl treesit-language-source-alist)
            original-registered-source))))

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

(ert-deftest go-template-ts-mode-does-not-warn-for-incomplete-control-action ()
  (skip-unless (treesit-ready-p 'gotmpl))
  (let ((treesit-font-lock-level 4))
    (with-temp-buffer
      (insert "{{ if eq .chezmoi.os \"android\" -}}")
      (go-template-ts-mode)
      (font-lock-ensure)
      (dotimes (offset (buffer-size))
        (should-not (eq (get-text-property (1+ offset) 'face)
                        'font-lock-warning-face))))))

(ert-deftest go-template-ts-mode-highlights-keywords-at-default-level ()
  (skip-unless (treesit-ready-p 'gotmpl))
  (let ((treesit-font-lock-level 3))
    (with-temp-buffer
      (insert "{{ end }}")
      (go-template-ts-mode)
      (font-lock-ensure)
      (goto-char (point-min))
      (search-forward "end")
      (should (eq (get-text-property (1- (point)) 'face)
                  'font-lock-keyword-face)))))

(ert-deftest go-template-ts-mode-highlights-keywords-in-indirect-buffers ()
  (skip-unless (treesit-ready-p 'gotmpl))
  (let ((treesit-font-lock-level 4))
    (with-temp-buffer
      (insert "x{{ end }}y")
      (let ((indirect (clone-indirect-buffer " *gotmpl-indirect*" nil)))
        (unwind-protect
            (with-current-buffer indirect
              (narrow-to-region 2 11)
              (go-template-ts-mode)
              (font-lock-ensure)
              (goto-char (point-min))
              (search-forward "end")
              (should (eq (get-text-property (1- (point)) 'face)
                          'font-lock-keyword-face)))
          (kill-buffer indirect))))))

(ert-deftest go-template-ts-mode-highlights-builtins-at-level-four ()
  (skip-unless (treesit-ready-p 'gotmpl))
  (let ((treesit-font-lock-level 4))
    (with-temp-buffer
      (insert "x{{ printf \"%s\" .Value }} {{ custom }}y")
      (let ((indirect (clone-indirect-buffer " *gotmpl-indirect*" nil)))
        (unwind-protect
            (with-current-buffer indirect
              (narrow-to-region 2 (1- (point-max)))
              (go-template-ts-mode)
              (font-lock-ensure)
              (goto-char (point-min))
              (search-forward "printf")
              (should (eq (get-text-property (1- (point)) 'face)
                          'font-lock-builtin-face))
              (search-forward "custom")
              (should (eq (get-text-property (1- (point)) 'face)
                          'font-lock-function-call-face)))
          (kill-buffer indirect))))))

(ert-deftest go-template-ts-mode-registers-treesit-fold-ranges ()
  (let ((ranges (alist-get 'go-template-ts-mode treesit-fold-range-alist)))
    (dolist (type '(if_action range_action with_action
                    define_action block_action))
      (should (eq (alist-get type ranges)
                  #'go-template-ts-mode-treesit-fold-range-action)))))

(ert-deftest go-template-ts-mode-computes-treesit-fold-range ()
  (skip-unless (treesit-ready-p 'gotmpl))
  (with-temp-buffer
    (insert "{{ if .enabled }}\nbody\n{{ end }}")
    (go-template-ts-mode)
    (let* ((node (treesit-search-subtree
                  (treesit-buffer-root-node 'gotmpl) "if_action"))
           (range (go-template-ts-mode-treesit-fold-range-action
                   node '(0 . 0))))
      (should (equal (buffer-substring-no-properties
                      (car range) (cdr range))
                     "\nbody\n")))))

(provide 'go-template-ts-mode-test)
;;; go-template-ts-mode-test.el ends here
