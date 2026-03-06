import NitroModules

// Workaround for a Nitro Modules upstream issue.
//
// Nitrogen-generated Swift code (e.g. Func_void_std__vector_Track_.swift) calls
// .map() on std::vector<T>, which requires CxxRandomAccessCollection conformance.
// Swift's C++ interop synthesizes this conformance lazily, but in incremental
// builds the conformance may not be available in the compilation batch that needs
// it, causing: "Value of type 'std::vector<T>' has no member 'map'"
//
// This should be fixed upstream in Nitro Modules. Until then, explicitly
// declaring the conformance here guarantees it's available regardless of
// compilation order.
//
// To identify which types need conformance, search the generated Swift files for
// .map() calls on bridge.std__vector_<T>_ types:
//
//   grep -r '\.map(' nitrogen/generated/ios/swift/ | grep std__vector

extension margelo.nitro.audiobrowser.bridge.swift.std__vector_Track_: @retroactive CxxRandomAccessCollection {}
