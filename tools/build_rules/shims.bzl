load("@bazel_gazelle//:deps.bzl", _go_repository = "go_repository")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")
load("@io_bazel_rules_go//go:def.bzl", _go_binary = "go_binary", _go_library = "go_library", _go_test = "go_test")

def go_repository(name, importpath, commit = None, custom = None, custom_git = None, tag = None, **kwargs):
    """Macro wrapping the Gazelle go_repository rule.  Works identically, except
    if custom is provided, an extra git_repository of that name is declared with
    an overlay built using the "third_party/go:<custom>.BUILD" file.
    """
    if (not commit) == (not tag):
        fail("Exactly one of commit= or tag= must be specified")

    _go_repository(
        name = name,
        commit = commit,
        importpath = importpath,
        tag = tag,
        **kwargs
    )
    if custom != None:
        if custom_git == None:
            custom_git = "https://" + importpath + ".git"
        new_git_repository(
            name = "go_" + custom,
            build_file = "@io_kythe//third_party/go:" + custom + ".BUILD",
            commit = commit,
            remote = custom_git,
            tag = tag,
        )

# Go importpath prefix shared by all Kythe libraries
go_prefix = "kythe.io/"

def _infer_importpath(name):
    basename = native.package_name().split("/")[-1]
    importpath = go_prefix + native.package_name()
    if basename == name:
        return importpath
    return importpath + "/" + name

def go_binary(name, importpath = None, **kwargs):
    """This macro wraps the go_binary rule provided by the Bazel Go rules to
    automatically infer the binary's importpath.  It is otherwise equivalent in
    function to a go_binary.
    """
    if importpath == None:
        importpath = _infer_importpath(name)
    _go_binary(
        name = name,
        importpath = importpath,
        out = name,
        **kwargs
    )

def go_library(name, importpath = None, **kwargs):
    """This macro wraps the go_library rule provided by the Bazel Go rules to
    automatically infer the library's importpath.  It is otherwise equivalent in
    function to a go_library.
    """
    if importpath == None:
        importpath = _infer_importpath(name)
    _go_library(
        name = name,
        importpath = importpath,
        **kwargs
    )

def go_test(name, library = None, **kwargs):
    """This macro wraps the go_test rule provided by the Bazel Go rules
    to silence a deprecation warning for use of the "library" attribute.
    It is otherwise equivalent in function to a go_test.
    """

    # For internal tests (defined in the same package), we need to embed
    # the library under test, but this is not needed for external tests.
    embed = [library] if library else []

    _go_test(
        name = name,
        embed = embed,
        **kwargs
    )
