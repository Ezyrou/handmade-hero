// I use Zig base types for integers in favor of C ABI compatible types because
// this code is intended for x64 Windows only. Moreover, Microsoft seems to
// define integer type sizes explicitly according to:
// https://learn.microsoft.com/en-us/windows/win32/winprog/windows-data-types
//
// For example, INT is typedefed as "int" but is also said to be a 32-bit signed
// integer, and its range is specified, so I use i32 instead of c_int.

// Mapping all the Windows error codes is one thing I don't want to do,
// so I'll use the mapping from the standard library.
pub const Win32Error = @import("std").os.windows.Win32Error;

pub const ATOM = u16;
pub const BOOL = i32;
pub const LPARAM = isize;
pub const WPARAM = usize;
pub const LRESULT = isize;

pub const HCURSOR = *opaque {};
pub const HDC = *opaque {};
pub const HINSTANCE = *opaque {};
pub const HWND = *opaque {};

pub const CS_HREDRAW: u32 = 0x0002;
pub const CS_VREDRAW: u32 = 0x0001;
pub const CS_OWNDC: u32 = 0x0020;

// A cursor to be used as input to LoadCursorW when creating
// a window class. Cursor identifiers are listed here:
// https://learn.microsoft.com/en-us/windows/win32/menurc/about-cursors
//
// IDC_ARROW is defined in WinUser.h as MAKEINTRESOURCE(32512).
// MAKEINTRESOURCEW is the following macro in the same file:
// ((LPWSTR)((ULONG_PTR)((WORD)(i)))).
pub const IDC_ARROW: [*:0]align(1) const u16 = @ptrFromInt(@as(usize, 32512));

pub const WS_CAPTION: u32 = 0x00C00000;
pub const WS_MAXIMIZEBOX: u32 = 0x00010000;
pub const WS_MINIMIZEBOX: u32 = 0x00020000;
pub const WS_OVERLAPPED: u32 = 0x00000000;
pub const WS_SYSMENU: u32 = 0x00080000;
pub const WS_THICKFRAME: u32 = 0x00040000;
pub const WS_VISIBLE: u32 = 0x10000000;

pub const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;

pub const CW_USEDEFAULT: i32 = -0x80000000;

pub const WM_CLOSE: u32 = 0x0010;
pub const WM_DESTROY: u32 = 0x0002;
pub const WM_PAINT: u32 = 0x000F;

pub const BLACKNESS: u32 = 0x00000042;
pub const WHITENESS: u32 = 0x00FF0062;

pub const MSG = extern struct {
    hwnd: ?HWND,
    message: u32,
    wParam: WPARAM,
    lParam: LPARAM,
    time: u32,
    pt: POINT,
};

pub const PAINTSTRUCT = extern struct {
    hdc: HDC,
    fErase: BOOL,
    rcPaint: RECT,
    fRestore: BOOL,
    fIncUpdate: BOOL,
    rgbReserved: [32]u8,
};

pub const POINT = extern struct {
    x: i32,
    y: i32,
};

pub const RECT = extern struct {
    left: i32,
    top: i32,
    right: i32,
    bottom: i32,
};

pub const WNDCLASSW = extern struct {
    style: u32,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32,
    cbWndExtra: i32,
    hInstance: HINSTANCE,
    hIcon: *opaque {},
    hCursor: HCURSOR,
    hbrBackground: *opaque {},
    lpszMenuName: [*:0]const u16,
    lpszClassName: [*:0]const u16,
};

// According to the compiler error I was getting, an extern struct like WNDCLASSW
// cannot contain a function pointer that does not specify a calling convention.
pub const WNDPROC = *const fn (
    hWnd: HWND,
    uMsg: u32,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(.winapi) LRESULT;

// Extern functions get the default C calling convention for the target by default,
// so I'm not specifying the callconv here, but I could set it to winapi.
pub extern "user32" fn BeginPaint(
    hWnd: HWND,
    lpPaint: *PAINTSTRUCT,
) ?HDC;

pub extern "user32" fn CreateWindowExW(
    dwExStyle: u32,
    lpClassName: ?[*:0]const u16,
    lpWindowName: ?[*:0]const u16,
    dwStyle: u32,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    hWndParent: ?HWND,
    hMenu: ?*opaque {},
    hInstance: ?HINSTANCE,
    lpParam: ?*anyopaque,
) ?HWND;

pub extern "user32" fn DefWindowProcW(
    hWnd: HWND,
    Msg: u32,
    wParam: WPARAM,
    lParam: LPARAM,
) LRESULT;

pub extern "user32" fn DestroyWindow(
    hWnd: HWND,
) BOOL;

pub extern "user32" fn DispatchMessageW(
    lpMsg: *const MSG,
) LRESULT;

pub extern "user32" fn EndPaint(
    hWnd: HWND,
    lpPaint: *const PAINTSTRUCT,
) BOOL;

pub extern "kernel32" fn GetLastError() Win32Error;

pub extern "user32" fn GetMessageW(
    lpMsg: *MSG,
    hWnd: ?HWND,
    wMsgFilterMin: u32,
    wMsgFilterMax: u32,
) BOOL;

pub extern "user32" fn LoadCursorW(
    hInstance: ?HINSTANCE,
    lpCursorName: [*:0]align(1) const u16,
) HCURSOR;

pub extern "gdi32" fn PatBlt(
    hdc: HDC,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    rop: u32,
) BOOL;

pub extern "user32" fn PostQuitMessage(
    nExitCode: i32,
) void;

pub extern "user32" fn RegisterClassW(
    lpWndClass: *const WNDCLASSW,
) ATOM;

pub extern "user32" fn TranslateMessage(
    lpMsg: *const MSG,
) BOOL;
