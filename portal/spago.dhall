{-
Welcome to a Spago project!
You can edit this file as you like.
-}
{ name = "my-project"
, dependencies =
    [ "affjax"
    , "argonaut"
    , "bigints"
    , "console"
    , "effect"
    , "generics-rep"
    , "halogen"
    , "http-methods"
    , "psci-support"
    , "routing"
    , "routing-duplex"
    ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs", "test/**/*.purs" ]
}
