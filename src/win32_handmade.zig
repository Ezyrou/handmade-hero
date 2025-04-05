const std = @import("std");
const w = std.os.windows;
const L = std.unicode.utf8ToUtf16LeStringLiteral;

const MB_OK: c_uint = 0x00000000;
const MB_ICONINFORMATION: c_uint = 0x00000040;

extern "user32" fn MessageBoxW(
    hWnd: ?w.HWND,
    lpText: ?w.LPCWSTR,
    lpCaption: ?w.LPCWSTR,
    uType: c_uint,
) c_int;

pub fn wWinMain(_: w.HINSTANCE, _: ?w.HINSTANCE, _: w.PWSTR, _: c_int) c_int {
    _ = MessageBoxW(null, L("This is Handmade Hero"), L("Handmade Hero"), MB_OK | MB_ICONINFORMATION);

    return 0;
}
