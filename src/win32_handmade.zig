const std = @import("std");
const w = std.os.windows;

// I use L as a shorthand here as it seems to be common in Zig std.
// It mimics the L prefix used in C++ for wide string literals.
const L = std.unicode.utf8ToUtf16LeStringLiteral;

// Some Windows API bindings are implemented in std.os.windows. However,
// they are kept to the minimum to facilitate maintainability.
//
// I plan to write the missing bindings and definitions myself as a
// learning process for now. One other option would be to use
// https://github.com/marlersoft/zigwin32 instead.
const MB_OK: c_uint = 0x00000000;
const MB_ICONINFORMATION: c_uint = 0x00000040;

// I plan to only use W functions as it seems to be the direction Zig has taken:
// https://github.com/ziglang/zig/issues/534
//
// Moreover, a comment in this issue implies it makes more sense to call W
// fonctions directly because it skips the conversion by Windows from A to
// W, and because some W fonctions have better support than their A counterpart.
//
// This is also what is recommended by Microsoft:
// https://learn.microsoft.com/en-us/windows/win32/learnwin32/working-with-strings
//
// This means I'll call utf8ToUtf16LeStringLiteral for string input parameters
// to these functions, but I'm guessing there is no runtime penalty because
// utf8ToUtf16LeStringLiteral returns a comptime block and probably gets
// inlined in release builds.
extern "user32" fn MessageBoxW(
    hWnd: ?w.HWND,
    lpText: ?w.LPCWSTR,
    lpCaption: ?w.LPCWSTR,
    uType: c_uint,
) c_int;

// wWinMain can be used in Zig instead of main(). Zig will detect it and invoke
// call_wWinMain, which will call us with the right parameters.
//
// I don't need to use the more portable main() entrypoint because wWinMain
// will only contain Windows specific code.
pub fn wWinMain(_: w.HINSTANCE, _: ?w.HINSTANCE, _: w.PWSTR, _: c_int) c_int {
    _ = MessageBoxW(null, L("This is Handmade Hero"), L("Handmade Hero"), MB_OK | MB_ICONINFORMATION);

    return 0;
}
