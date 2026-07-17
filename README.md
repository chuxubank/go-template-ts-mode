# go-template-ts-mode

`go-template-ts-mode` is an Emacs 29+ major mode for Go
[`text/template`](https://pkg.go.dev/text/template) and
[`html/template`](https://pkg.go.dev/html/template) files. It uses the
[`gotmpl`](https://github.com/ngalaiko/tree-sitter-go-template) tree-sitter
grammar.

The mode provides tree-sitter font locking, indentation, comments, defun
navigation, and Imenu entries for named templates and blocks.

## Installation

Install directly from GitHub with `package-vc`:

```elisp
(use-package go-template-ts-mode
  :vc (:url "https://github.com/chuxubank/go-template-ts-mode"))
```

Then install the grammar once:

```text
M-x go-template-ts-mode-install-grammar
```

Files ending in `.gotmpl` or `.tmpl` automatically use `go-template-ts-mode`.

## Polymode

For templates that should retain the host language's mode, such as
`deployment.yaml.gotmpl`, use `poly-any-go-template` from
[`cat-emacs`](https://github.com/chuxubank/cat-emacs).

## License

GPL-3.0-or-later. The tree-sitter grammar is a separate project and is not
bundled with this package.
