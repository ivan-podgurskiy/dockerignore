# Used by "mix format". unicode15.ex stays byte-stable for deterministic Go generation.
[
  inputs: [
    "{mix,.formatter}.exs",
    "lib/dockerignore.ex",
    "lib/dockerignore/{compiler,error,filepath,glob,matcher,parser,path,pattern,utf8}.ex",
    "{config,test}/**/*.{ex,exs}"
  ]
]
