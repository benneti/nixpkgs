{ lib
, callPackage
, runCommand
, fetchFromGitHub
, fetchgit
, git
, makeWrapper
, writeTextFile
, python3

, julia
, extraLibs ? []
, packageNames ? ["IJulia" "Plots"]
, precompile ? true
, makeWrapperArgs ? ""
}:

let
  # Special registry which is equal to JuliaRegistries/General, but every Versions.toml
  # entry is augmented with a Nix sha256 hash
  augmentedRegistry = callPackage ./registry.nix {};

  # Invoke Julia resolution logic to determine the full dependency closure
  closureYaml = callPackage ./package-closure.nix {
    inherit julia augmentedRegistry packageNames;
  };

  # Generate a Nix file consisting of a map from dependency UUID --> fetchgit call:
  # {
  #   "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3" = fetchgit {...};
  #   ...
  # }
  dependencies = runCommand "julia-sources.nix" { buildInputs = [(python3.withPackages (ps: with ps; [toml pyyaml]))]; } ''
    export OUT="$out"
    python ${./sources_nix.py} \
      "${augmentedRegistry}" \
      "${closureYaml}" \
      "$out"
  '';

  # Import the Nix file from the previous step (IFD) and turn each dependency repo into
  # a dummy Git repository, as Julia expects. Format the results as a YAML map from
  # dependency UUID -> Nix store location:
  # {
  #   "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3":"/nix/store/...-NaNMath.jl-0877504",
  #   ...
  # }
  dependenciesYaml = writeTextFile {
    name = "julia-dependencies.yml";
    text = lib.generators.toYAML {} (lib.mapAttrs repoify (import dependencies { inherit fetchgit; }));
  };
  repoify = name: src:
    runCommand ''julia-${name}-repoified'' {buildInputs = [git];} ''
      mkdir -p $out
      cp -r ${src}/. $out
      cd $out
      git init
      git add . -f
      git config user.email "julia2nix@localhost"
      git config user.name "julia2nix"
      git commit -m "Dummy commit"
    '';

  # Given the augmented registry, closure info yaml, and dependency path yaml, construct a complete
  # Julia registry containing all the necessary packages
  minimalRegistry = runCommand "minimal-julia-registry" { buildInputs = [(python3.withPackages (ps: with ps; [toml pyyaml]))]; } ''
    python ${./minimal_registry.py} \
      "${augmentedRegistry}" \
      "${closureYaml}" \
      "${dependenciesYaml}" \
      "$out"
  '';

  # Next, deal with artifacts. Scan each artifacts file individually.

  # Build a Julia project and depot. The project contains Project.toml/Manifest.toml, while the
  # depot contains package build products (including the precompiled libraries, if precompile=true)
  projectAndDepot = callPackage ./depot.nix {
    inherit extraLibs packageNames precompile;
    registry = minimalRegistry;
  };

in

runCommand "julia-${julia.version}-env" { buildInputs = [makeWrapper]; } ''
  mkdir -p $out/bin
  makeWrapper ${julia}/bin/julia $out/bin/julia \
    --suffix LD_LIBRARY_PATH : "${lib.makeLibraryPath extraLibs}" \
    --set PYTHON ${python3}/bin/python \
    --suffix JULIA_DEPOT_PATH : "${projectAndDepot}/depot" \
    --suffix JULIA_PROJECT : "${projectAndDepot}/project" \
    --suffix PATH : ${python3}/bin $makeWrapperArgs
''
