-- Build the Makefile language server locally; Lazy manages its revision and binary.
return {
  'owenrumney/make-ls',
  lazy = true,
  build = 'go build -o make-ls ./cmd/make-ls',
}
