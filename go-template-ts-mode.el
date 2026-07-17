;;; go-template-ts-mode.el --- Tree-sitter mode for Go templates -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka

;; Author: Misaka <chuxubank@qq.com>
;; Maintainer: Misaka <chuxubank@qq.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, go, templates, tree-sitter
;; URL: https://github.com/chuxubank/go-template-ts-mode

;;; Commentary:

;; A tree-sitter major mode for Go text/template and html/template files.
;; It uses the `gotmpl' grammar from
;; https://github.com/ngalaiko/tree-sitter-go-template.
;;
;; Install the grammar with:
;;
;;   M-x go-template-ts-mode-install-grammar

;;; Code:

(require 'treesit)
(eval-when-compile (require 'rx))

(defgroup go-template-ts nil
  "Major mode for Go templates, powered by tree-sitter."
  :group 'languages
  :prefix "go-template-ts-mode-")

(defcustom go-template-ts-mode-indent-offset 2
  "Number of spaces for each indentation step."
  :type 'integer
  :safe #'integerp
  :group 'go-template-ts)

(defcustom go-template-ts-mode-grammar-source
  '("https://github.com/ngalaiko/tree-sitter-go-template")
  "Source used to install the `gotmpl' tree-sitter grammar.
The value has the same form as the cdr of an entry in
`treesit-language-source-alist'."
  :type '(repeat string)
  :group 'go-template-ts)

(add-to-list 'treesit-language-source-alist
             (cons 'gotmpl go-template-ts-mode-grammar-source))

(defconst go-template-ts-mode--keywords
  '("block" "break" "continue" "define" "else" "end" "if" "range"
    "template" "with"))

(defconst go-template-ts-mode--builtins
  '("and" "call" "eq" "ge" "gt" "html" "index" "js" "le" "len" "lt"
    "ne" "not" "or" "print" "printf" "println" "slice" "urlquery"))

(defvar go-template-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?_ "w" table)
    (modify-syntax-entry ?$ "_" table)
    (modify-syntax-entry ?' "\"" table)
    (modify-syntax-entry ?` "\"" table)
    table)
  "Syntax table for `go-template-ts-mode'.")

(defun go-template-ts-mode--closing-action-p (_node _parent bol)
  "Return non-nil when the line at BOL start an else or end action."
  (save-excursion
    (goto-char bol)
    (back-to-indentation)
    (looking-at-p "{{-?[[:space:]]*\\(?:else\\|end\\)\\_>")))

(defconst go-template-ts-mode--indent-node-types
  '("argument_list" "parenthesized_pipeline" "if_action" "range_action"
    "with_action" "define_action" "block_action"))

(defun go-template-ts-mode--indent-depth (_node parent bol)
  "Return the indentation depth implied by PARENT at BOL."
  (let ((depth 0))
    (while parent
      (when (and (member (treesit-node-type parent)
                         go-template-ts-mode--indent-node-types)
                 (< (treesit-node-start parent) bol))
        (setq depth (1+ depth)))
      (setq parent (treesit-node-parent parent)))
    (* depth go-template-ts-mode-indent-offset)))

(defun go-template-ts-mode--closing-indent-depth (node parent bol)
  "Return indentation depth for closing action NODE with PARENT at BOL."
  (max 0 (- (go-template-ts-mode--indent-depth node parent bol)
            go-template-ts-mode-indent-offset)))

(defvar go-template-ts-mode--indent-rules
  `((gotmpl
     ((parent-is "template") column-0 0)
     ((parent-is "raw_string_literal") no-indent 0)
     (go-template-ts-mode--closing-action-p
      column-0 go-template-ts-mode--closing-indent-depth)
     (catch-all column-0 go-template-ts-mode--indent-depth)
     (no-node parent-bol 0)))
  "Tree-sitter indentation rules for `go-template-ts-mode'.")

(defvar go-template-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'gotmpl
   :feature 'comment
   :override t
   '((comment) @font-lock-comment-face)

   :language 'gotmpl
   :feature 'keyword
   :override t
   `([,@go-template-ts-mode--keywords] @font-lock-keyword-face)

   :language 'gotmpl
   :feature 'builtin
   :override t
   `((function_call
      function: ((identifier) @font-lock-builtin-face
                 (:match ,(rx-to-string
                           `(seq string-start
                                 (or ,@go-template-ts-mode--builtins)
                                 string-end))
                         @font-lock-builtin-face))))

   :language 'gotmpl
   :feature 'definition
   :override t
   '((define_action name: [(interpreted_string_literal)
                           (raw_string_literal)] @font-lock-function-name-face)
     (block_action name: [(interpreted_string_literal)
                          (raw_string_literal)] @font-lock-function-name-face)
     (variable_definition variable: (variable) @font-lock-variable-name-face)
     (range_variable_definition
      index: (variable) @font-lock-variable-name-face
      element: (variable) @font-lock-variable-name-face))

   :language 'gotmpl
   :feature 'function
   :override t
   '((function_call function: (identifier) @font-lock-function-call-face)
     (method_call method: (field (identifier) @font-lock-function-call-face))
     (method_call
      method: (selector_expression
               field: (field_identifier) @font-lock-function-call-face)))

   :language 'gotmpl
   :feature 'property
   :override t
   '((field (identifier) @font-lock-property-use-face)
     (field_identifier) @font-lock-property-use-face)

   :language 'gotmpl
   :feature 'variable
   :override t
   '((variable) @font-lock-variable-use-face)

   :language 'gotmpl
   :feature 'constant
   :override t
   '([(true) (false) (nil)] @font-lock-constant-face)

   :language 'gotmpl
   :feature 'number
   :override t
   '([(int_literal) (float_literal) (imaginary_literal)] @font-lock-number-face)

   :language 'gotmpl
   :feature 'string
   :override t
   '([(interpreted_string_literal) (raw_string_literal) (rune_literal)]
     @font-lock-string-face)

   :language 'gotmpl
   :feature 'escape-sequence
   :override t
   '((escape_sequence) @font-lock-escape-face)

   :language 'gotmpl
   :feature 'operator
   :override t
   '(["|" ":=" "="] @font-lock-operator-face)

   :language 'gotmpl
   :feature 'bracket
   :override t
   '(["{{" "{{-" "}}" "-}}" "(" ")"] @font-lock-bracket-face)

   :language 'gotmpl
   :feature 'delimiter
   :override t
   '(["." ","] @font-lock-delimiter-face)

   :language 'gotmpl
   :feature 'error
   :override t
   '((ERROR) @font-lock-warning-face))
  "Tree-sitter font-lock settings for `go-template-ts-mode'.")

(defun go-template-ts-mode--defun-name (node)
  "Return the template name declared by NODE."
  (when-let* ((name-node (treesit-node-child-by-field-name node "name"))
              (name (treesit-node-text name-node t)))
    (string-trim name "[`\"]+" "[`\"]+")))

;;;###autoload
(defun go-template-ts-mode-install-grammar ()
  "Install or update the `gotmpl' tree-sitter grammar."
  (interactive)
  (treesit-install-language-grammar 'gotmpl))

;;;###autoload
(define-derived-mode go-template-ts-mode prog-mode "Go-Template[TS]"
  "Major mode for Go templates, powered by tree-sitter."
  :group 'go-template-ts
  :syntax-table go-template-ts-mode--syntax-table

  (setq-local comment-start "{{/* ")
  (setq-local comment-end " */}}")
  (setq-local comment-start-skip "{{-?[[:space:]]*/\\*+[[:space:]]*")
  (setq-local comment-end-skip "[[:space:]]*\\*+/[[:space:]]*-?}}")
  (setq-local indent-tabs-mode nil)

  (when (treesit-ready-p 'gotmpl)
    (treesit-parser-create 'gotmpl)

    (setq-local treesit-simple-indent-rules go-template-ts-mode--indent-rules)
    (setq-local treesit-defun-type-regexp
                (regexp-opt '("define_action" "block_action")))
    (setq-local treesit-defun-name-function
                #'go-template-ts-mode--defun-name)
    (setq-local treesit-simple-imenu-settings
                '(("Template" "\\`define_action\\'" nil nil)
                  ("Block" "\\`block_action\\'" nil nil)))

    (setq-local treesit-font-lock-settings
                go-template-ts-mode--font-lock-settings)
    (setq-local treesit-font-lock-feature-list
                '((comment definition)
                  (keyword string)
                  (builtin constant escape-sequence number)
                  (bracket delimiter error function operator property variable)))

    (treesit-major-mode-setup)))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.gotmpl\\'" . go-template-ts-mode))

(provide 'go-template-ts-mode)
;;; go-template-ts-mode.el ends here
