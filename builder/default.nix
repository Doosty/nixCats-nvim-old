# Copyright (c) 2023 BirdeeHub 
# Licensed under the MIT license 
{ 
  self
  , pkgs
  , categories ? {}
  , settings ? {}
  , startupPlugins ? {}
  , optionalPlugins ? {}
  , lspsAndRuntimeDeps ? {}
  , propagatedBuildInputs ? {}
  , environmentVariables ? {}
  , extraWrapperArgs ? {}
  # the source says:
    /* the function you would have passed to python.withPackages */
  # So you put in a set of categories of lists of them.
  , extraPythonPackages ? {}
  , extraPython3Packages ? {}
  # same thing except for lua.withPackages
  , extraLuaPackages ? {}
  }:
  # for a more extensive guide to this file
  # see :help nixCats.flake.nixperts.nvimBuilder
  let
    config = {
      wrapRc = true;
      RCName = "";
      viAlias = false;
      vimAlias = false;
      withNodeJs = false;
      withRuby = true;
      extraName = "";
      withPython3 = true;
    } // settings;

    # package the entire flake as plugin
    LuaConfig = pkgs.stdenv.mkDerivation {
        name = config.RCName;
        builder = builtins.toFile "builder.sh" ''
          source $stdenv/setup
          mkdir -p $out
          cp -r ${self}/* $out
        '';
      };

    # see :help nixCats
    nixCats = pkgs.stdenv.mkDerivation {
      name = "nixCats";
      builder = let
        cats = builtins.toFile "nixCats.lua" ''
            vim.api.nvim_create_user_command('NixCats', 
            [[lua print(vim.inspect(require('nixCats')))]] , 
            { desc = 'So Cute!' })
            return ${(import ./utils.nix).luaTablePrinter categories}
          '';
      in builtins.toFile "builder.sh" ''
        source $stdenv/setup
        mkdir -p $out/lua
        mkdir -p $out/doc
        cp ${cats} $out/lua/nixCats.lua
        cp -r ${self}/nixCatsHelp/* $out/doc
      '';
    };

    wrapRc = if config.RCName != "" then config.wrapRc else false;

    # and create our customRC to call it
    customRC = if wrapRc then ''lua require('${config.RCName}')'' else "";

    extraPlugins = if wrapRc then [ nixCats LuaConfig ] else [ nixCats ];

    # this is what allows for dynamic packaging in flake.nix
    # It includes categories marked as true, then flattens to a single list
    filterAndFlatten = (import ./utils.nix)
          .filterAndFlattenAttrsOfLists pkgs categories;

    # I didnt add stdenv.cc.cc.lib, so I would suggest not removing it.
    # It has cmake in it I think among other things?
    buildInputs = [ pkgs.stdenv.cc.cc.lib ] ++ filterAndFlatten propagatedBuildInputs;
    start = extraPlugins ++ filterAndFlatten startupPlugins;
    opt = filterAndFlatten optionalPlugins;

    # For wrapperArgs:
    # This one filters and flattens like above but for attrs of attrs 
    # and then maps name and value
    # into a list based on the function we provide it.
    # its like a flatmap function but with a built in filter for category.
    filterAndFlattenWrapAttrs = (import ./utils.nix)
          .FilterAttrsOfAttrsFlatMapInner pkgs categories;
    # This one filters and flattens attrs of lists and then maps value
    # into a list of strings based on the function we provide it.
    # it the same as above but for a mapping function with 1 argument
    # because the inner is a list not a set.
    filterAndFlattenWrapLists = (import ./utils.nix)
          .FilterAttrsOfListsFlatMapInner pkgs categories;

    # and then applied:

    FandF_envVarSet = filterAndFlattenWrapAttrs 
          (name: value: ''--set ${name} "${value}"'');

    FandF_passWrapperArgs = filterAndFlattenWrapLists (value: value);

    # add any dependencies/lsps/whatever we need available at runtime
    FandF_WrapRuntimeDeps = filterAndFlattenWrapLists (value:
      ''--prefix PATH : "${pkgs.lib.makeBinPath [ value ] }"''
    );

    # extraPythonPackages and the like require FUNCTIONS that return lists.
    # so we make a function that returns a function that returns lists.
    # this is used for the fields in the wrapper where the default value is (_: [])
    combineCatsOfFuncs = sect:
      (x: let
        appliedfunctions = builtins.map (value: (value) x ) (filterAndFlatten sect);
        combinedFuncRes = builtins.concatLists appliedfunctions;
        uniquifiedList = pkgs.lib.unique combinedFuncRes;
      in
      uniquifiedList);

    # cat our args
    extraMakeWrapperArgs = builtins.concatStringsSep " " (
      (FandF_WrapRuntimeDeps lspsAndRuntimeDeps)
      ++ (FandF_envVarSet environmentVariables)
      ++ (FandF_passWrapperArgs extraWrapperArgs)
      # https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/setup-hooks/make-wrapper.sh
    );

    # add our propagated build dependencies
    myNeovimUnwrapped = pkgs.neovim-unwrapped.overrideAttrs (prev: {
      propagatedBuildInputs = buildInputs;
    });

  in
  # add our lsps and plugins and our config, and wrap it all up!
(import ./wrapNeovim.nix).wrapNeovim pkgs myNeovimUnwrapped {
  inherit wrapRc extraMakeWrapperArgs;
  inherit (config) vimAlias viAlias withRuby extraName withNodeJs;
  configure = {
    inherit customRC;
    packages.myVimPackage = {
      inherit start opt;
    };
  };
  # I dont know what these do, but I implemented them?
    /* the function you would have passed to python.withPackages */
  extraPythonPackages = combineCatsOfFuncs extraPythonPackages;
    /* the function you would have passed to python.withPackages */
  withPython3 = config.withPython3;
  extraPython3Packages = combineCatsOfFuncs extraPython3Packages;
    /* the function you would have passed to lua.withPackages */
  extraLuaPackages = combineCatsOfFuncs extraLuaPackages;
}
