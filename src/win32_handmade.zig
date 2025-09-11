const std = @import("std");
const w = @import("win32_bindings.zig");
const L = std.unicode.utf8ToUtf16LeStringLiteral;

// I sometimes temporarily set functions as noinline to prevent inlining,
// so I can more easily debug them in release mode to inspect what the
// output assembly code looks like.
pub noinline fn wWinMain(instance: w.HINSTANCE, _: ?w.HINSTANCE, _: [*:0]u16, _: i32) i32 {
    // Initializing a WNDCLASSW struct to zero. It contains non-optional
    // pointers, but the compiler won't complain because it's an extern
    // struct. See https://github.com/ziglang/zig/issues/6202.
    //
    // Care must be taken to set the necessary pointers (lpfnWndProc in
    // this case) before passing the struct to Windows. Otherwise, Windows
    // could dereference them as null pointers and seg fault.
    var window_class = std.mem.zeroes(w.WNDCLASSW);

    // CS_HREDRAW and CS_VREDRAW will make it so that the whole window
    // is redrawn when changing its size, instead of just the newly
    // expanded section. This does not seem necessary for a game since
    // we want to draw the whole window every frame, and we probably
    // want to stay at fixed ratios anyway. I'll keep the flags here
    // for now for future reference. The effect of these two styles
    // can easily be seen with the black and white paint logic of the
    // current program.
    //
    // CS_OWNDC is recommended for performance sensitive applications
    // at some system memory cost, according to:
    // https://learn.microsoft.com/en-us/windows/win32/gdi/private-display-device-contexts
    //
    // When CS_OWNDC is set, GetDC only needs to be called once. The
    // DC handle can be stored for reuse, and ReleaseDC never needs to
    // be called. GetDC/ReleaseDC are first addressed on Day 4.
    //
    // These flags are latter discussed by Casey at the beginning of
    // Day 5 and the beginning of the Q&A of the same day.
    window_class.style = w.CS_HREDRAW | w.CS_VREDRAW | w.CS_OWNDC;

    // Here we tell Windows where the window procedure is for this window
    // class. All windows created from this class will have the same
    // procedure. An application thread can have more than one window class.
    //
    // Casey touches on how sometimes this procedure gets called without us
    // calling DispatchMessage during the Q&A at 30:18. It was confusing to
    // me because I did not understand his explanation of how the procedure
    // gets called in general.
    //
    // I was wondering how the application can be sure that the procedure
    // is not called concurrently if Windows can call it out of the blue.
    //
    // The way this works is pretty simple and well documented by Microsoft,
    // such as in this article:
    // https://learn.microsoft.com/en-us/windows/win32/winmsg/about-messages-and-message-queues
    //
    // There are two types of messages posted by Windows: queued and
    // nonqueued messages. The former are put in a FIFO queue and retrieved
    // by the application with GetMessage/PeekMessage. The later are sent
    // directly to the window procedure.
    //
    // The goal of GetMessage/PeekMessage is not just to retrieve the next
    // message in the queue, but also to immediately call the procedure on
    // nonqueued messages when there is one. So yeah, technically, nonqueued
    // messages still need to wait for an execution of GetMessage/PeekMessage
    // to be sent to the procedure.
    //
    // This means there are several ways that the procedure is called: most
    // of the calls are done through GetMessage/PeekMessage or DispatchMessage.
    // The procedure is also called during window initialization through
    // CreateWindowEx before the message queue is even created. This is why
    // the window procedure is always called from the main thread and never
    // concurrently. There is no such thing as an out of bound call from
    // Windows, it always goes through the application thread.
    //
    // I had to look at what happens in a debugger to really understand it,
    // by looking at the call stack like Casey shows in the Q&A. Using the
    // Windows public symbols is also interesting, to see what sort of path
    // the calls take through the operating system.
    //
    // This system seems to be pretty flexible:
    // - Window procedures can be called directly by Windows for messages
    //   that are only relevant to a specific window and should not wait for
    //   the queue such as WM_SETCURSOR (see Day 40 at 26:55).
    // - Queued messages that don't need to be dispatched to any window
    //   can be handled in the message loop directly.
    // - The others can be dispatched to their respective window procedure.
    // - There is separation of concerns where each window class has its
    //   own window procedure so they can handle their own logic.
    window_class.lpfnWndProc = wndProc;
    window_class.hInstance = instance;
    // Setting a cursor resource makes it so the cursor is reset every time
    // it enters the window. Otherwise, it will keep the shape it had before
    // entering, such as a resize shape.
    window_class.hCursor = w.LoadCursorW(null, w.IDC_ARROW);
    window_class.lpszClassName = L("HandmadeHeroWindowClass");

    if (w.RegisterClassW(&window_class) == 0) {
        // To get extended error information, we can call GetLastError when
        // the Microsoft documentation for the function explicitly says we can.
        std.log.err("failed to register window class: {t}", .{w.GetLastError()});
        return 0;
    }

    // It seems CreateWindowW is not even defined as a function in the Windows
    // header files anymore, so I use CreateWindowExW, even though I do not
    // need to use extended window styles.
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

    // This is the thread message loop. As soon as GetMessageW is called for the
    // first time, a message queue is created for the current thread, and messages
    // posted to the queue by Windows are expected to be handled within a few
    // seconds each. Failing to do so will result in the window being flagged
    // as not responding by Windows, which will replace it by a ghost window.
    while (true) {
        // At first I declared the message variable outside the message loop,
        // thinking that putting it inside would incur extra instructions for
        // every iteration. Then I watched Day 5, where Casey talks about this
        // at 12:10.
        //
        // In Zig at least, there is no assembly generated for such variable
        // declaration in release=fast mode. The compiler just reserves the
        // necessary space for the variable on the stack, regardless of where
        // it is declared in the function. The output assembly is exactly
        // the same with the variable declared inside or outside the loop.
        // So the place of declaration only matters for scoping in fast mode.
        //
        // In release=safe mode, the compiler inserts instructions to set the
        // contents of message to 0xaa bytes because it is undefined. This
        // is done where the declaration is, so in our case at every iteration.
        // There are even more instructions added to every iteration in debug mode.
        var message: w.MSG = undefined;
        // As explained in a previous comment, GetMessageW will look for nonqueued
        // messages and call the window procedure on them directly. Once there are
        // no more nonqueued messages, it will pop the next queued message, put it
        // in the MSG struct, and return. Once there are no more queued messages,
        // it will block until new ones are put in the queue.
        const result = w.GetMessageW(&message, null, 0, 0);
        // Following the documentation on GetMessageW, we handle the case when -1
        // is returned. This check won't be necessary later when we switch from
        // GetMessageW to PeekMessageW.
        if (result == -1) {
            std.log.err("failed to get message: {t}", .{w.GetLastError()});
            return 0;
        } else if (result != 0) {
            _ = w.TranslateMessage(&message);
            // This finds the window the message is for, looks up its window
            // procedure and calls it. This is blocking and only returns once
            // the window procedure returns.
            _ = w.DispatchMessageW(&message);
        } else {
            // If the result is 0, we received a WM_QUIT message, which is a
            // request to terminate the application.
            break;
        }
    }

    return 0;
}

// The window handle parameter allows the procedure to act on the window
// the message was intended for. If we had more than one window linked to
// the same callback, we would need to handle messages such as WM_CLOSE or
// WM_PAINT for the right window.
fn wndProc(window: w.HWND, message: u32, wparam: w.WPARAM, lparam: w.LPARAM) callconv(.winapi) w.LRESULT {
    var Result: w.LRESULT = 0;

    switch (message) {
        // Handle WM_CLOSE messages, which allows us to intercept the window
        // closing events. Casey mentions it during Q&A of day 2 at 8:00.
        w.WM_CLOSE => {
            // DestroyWindow sends WM_DESTROY to the queue.
            _ = w.DestroyWindow(window);
        },
        // The WM_DESTROY message indicates that the window is in the
        // process of being destroyed. At this point the window has
        // already been removed from the screen, so the goal of the
        // message is to trigger any necessary cleanup.
        w.WM_DESTROY => {
            // PostQuitMessage will post a WM_QUIT message to the thread
            // message queue. Casey mentions it during Q&A of day 2 at 19:38.
            w.PostQuitMessage(0);
        },
        // The WM_PAINT message indicates that a portion of the window needs
        // to be painted: the update region.
        w.WM_PAINT => {
            var paint: w.PAINTSTRUCT = undefined;

            // BeginPaint should only be used in response to WM_PAINT.
            if (w.BeginPaint(window, &paint)) |device_context| {
                // EndPaint tells Windows that the update region has been painted.
                defer _ = w.EndPaint(window, &paint);

                // Translate the coordinates of the update region into a rectangle.
                const x: i32 = paint.rcPaint.left;
                const y: i32 = paint.rcPaint.top;
                const width: i32 = paint.rcPaint.right - paint.rcPaint.left;
                const height: i32 = paint.rcPaint.bottom - paint.rcPaint.top;

                std.log.debug("x: {}, y: {}, width: {}, height: {}", .{ x, y, width, height });

                // This is how a local variable can have a static lifetime in Zig.
                // https://ziglang.org/documentation/master/#Static-Local-Variables
                const S = struct {
                    var operation: u32 = w.WHITENESS;
                };

                // Paint a rectangle into the device context. In our case, the
                // rectangle is the whole update region.
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
