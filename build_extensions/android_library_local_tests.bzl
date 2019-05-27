"""A rule wrapper for generating android_local_tests for an android library."""

load(
    "//build_extensions:infer_android_package_name.bzl",
    "infer_android_package_name",
)

_CONFIG_JAR_COMMAND = """
set -e
JAR="$(location @local_jdk//:jar)"
SRC="$<"
[[ "$$(basename "$${SRC}")" = 'robolectric.properties' ]] || {
  echo 'Must be named: robolectric.properties';
  exit 1;
}
$${JAR} -cf "$@" -C "$$(dirname "$${SRC}")" "$$(basename "$${SRC}")"
"""

def android_library_local_tests(name, srcs, deps, **kwargs):
    """A rule for generating android_local_tests whose target under test is an android_library.

    Intended to have similar semantics as android_library_instrumentation_tests

    This will generate:
      - a test_lib android_library, containing all sources and dependencies
      - the manifest to use for the test library.
      - an android_local_test rule for each src

    Args:
      name: the name to use for the generated android_library rule. This is needed for build_cleaner to
        manage dependencies
      srcs: the test sources to generate rules for
      deps: the build dependencies to use for the generated local test
      **kwargs: arguments to pass to generated android_local_test rules
    """

    android_package_name = infer_android_package_name()
    library_name = name
    _robolectric_config(
        name = "%s_config" % library_name,
        src = "//build_extensions:robolectric.properties",
    )
    native.android_library(
        name = library_name,
        srcs = srcs,
        testonly = 1,
        deps = deps + [
        ":%s_config" % library_name,
        "@robolectric//bazel:robolectric",
        ],
    )
    for src in srcs:
        # assume src has .java suffix
        name = src.rstrip(".java")
        native.android_local_test(
            name = name,
            tags = ["robolectric"],
            aapt_version = "aapt2",
            manifest = "//build_extensions:AndroidManifest_target_stub.xml",
            manifest_values = {"applicationId": android_package_name},
            deps = [
                library_name,
            ],
            **kwargs
        )

def _robolectric_config(name, src):
    """Creates a JAR file containing the given Robolectric properties file at the top level.

    Args:
      name: a string, the name of the rule
      src: a label, the properties file to package
    """
    native.genrule(
        name = name + "_gen",
        srcs = [src],
        outs = ["%s.jar" % name],
        message = "Generating Robolectric config...",
        cmd = _CONFIG_JAR_COMMAND,
        tools = [
            "@local_jdk//:jar",
        ],
        visibility = ["//visibility:private"],
    )
    native.java_import(
        name = name,
        constraints = ["android"],
        jars = [name + "_gen"],
    )
