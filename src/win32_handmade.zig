const std = @import("std");
const w = @import("win32_bindings.zig");
const L = std.unicode.utf8ToUtf16LeStringLiteral;

pub fn wWinMain(instance: w.HINSTANCE, _: ?w.HINSTANCE, _: [*:0]u16, _: i32) i32 {
    var window_class = std.mem.zeroes(w.WNDCLASSW);
    window_class.style = w.CS_HREDRAW | w.CS_VREDRAW | w.CS_OWNDC;
    window_class.lpfnWndProc = wndProc;
    window_class.hInstance = instance;
    window_class.hCursor = w.LoadCursorW(null, w.IDC_ARROW);
    window_class.lpszClassName = L("HandmadeHeroWindowClass");

    if (w.RegisterClassW(&window_class) == 0) {
        std.log.err("failed to register window class: {t}", .{w.GetLastError()});
        return 0;
    }

    _ = w.CreateWindowExW(
        0,
        window_class.lpszClassName,
        L("Handmade Hero"),
        w.WS_OVERLAPPEDWINDOW | w.WS_VISIBLE,
        w.CW_USEDEFAULT,
        w.CW_USEDEFAULT,
        w.CW_USEDEFAULT,
        w.CW_USEDEFAULT,
        null,
        null,
        instance,
        null,
    ) orelse {
        std.log.err("failed to create window: {t}", .{w.GetLastError()});
        return 0;
    };

    var message: w.MSG = undefined;

    while (true) {
        const result = w.GetMessageW(&message, null, 0, 0);
        if (result == -1) {
            std.log.err("failed to get message: {t}", .{w.GetLastError()});
            return 0;
        } else if (result != 0) {
            _ = w.TranslateMessage(&message);
            _ = w.DispatchMessageW(&message);
        } else {
            break;
        }
    }

    return 0;
}

fn wndProc(window: w.HWND, message: u32, wparam: w.WPARAM, lparam: w.LPARAM) callconv(w.WINAPI) w.LRESULT {
    var Result: w.LRESULT = 0;

    switch (message) {
        w.WM_CLOSE => {
            _ = w.DestroyWindow(window);
        },
        w.WM_DESTROY => {
            w.PostQuitMessage(0);
        },
        w.WM_PAINT => {
            var paint: w.PAINTSTRUCT = undefined;

            if (w.BeginPaint(window, &paint)) |device_context| {
                defer _ = w.EndPaint(window, &paint);

                const x: i32 = paint.rcPaint.left;
                const y: i32 = paint.rcPaint.top;
                const width: i32 = paint.rcPaint.right - paint.rcPaint.left;
                const height: i32 = paint.rcPaint.bottom - paint.rcPaint.top;

                std.log.debug("x: {}, y: {}, width: {}, height: {}", .{ x, y, width, height });

                const S = struct {
                    var operation: u32 = w.WHITENESS;
                };

                _ = w.PatBlt(device_context, x, y, width, height, S.operation);

                if (S.operation == w.WHITENESS) {
                    S.operation = w.BLACKNESS;
                } else {
                    S.operation = w.WHITENESS;
                }
            } else {
                std.log.err("failed to begin paint: no display device context available", .{});
            }
        },
        else => {
            Result = w.DefWindowProcW(window, message, wparam, lparam);
        },
    }

    return Result;
}
