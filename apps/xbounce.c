
#define _POSIX_C_SOURCE 200809L

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define WIN_W 360
#define WIN_H 160
#define BTN_X 130
#define BTN_Y 100
#define BTN_W 100
#define BTN_H 38

static Display *dpy;
static Window win;
static GC gc;
static XFontStruct *font;
static int sw, sh;
static int wx = 100, wy = 100;
static unsigned long bg, fg, accent;

static void text(int x, int y, const char *s)
{
    XSetForeground(dpy, gc, fg);
    XDrawString(dpy, win, gc, x, y, s, (int)__builtin_strlen(s));
}

static void draw(void)
{
    XSetForeground(dpy, gc, bg);
    XFillRectangle(dpy, win, gc, 0, 0, WIN_W, WIN_H);

    XSetForeground(dpy, gc, fg);
    XDrawRectangle(dpy, win, gc, 8, 8, WIN_W - 17, WIN_H - 17);

    const char *message = "Press OK to bounce window";
    int tw = XTextWidth(font, message, 26);

    text((WIN_W - tw) / 2, 53, message);

    XSetForeground(dpy, gc, accent);
    XFillRectangle(dpy, win, gc, BTN_X, BTN_Y, BTN_W, BTN_H);

    XSetForeground(dpy, gc, fg);
    XDrawRectangle(dpy, win, gc, BTN_X, BTN_Y, BTN_W, BTN_H);

    const char *label = "OK";
    int lw = XTextWidth(font, label, 2);

    text(BTN_X + (BTN_W - lw) / 2, BTN_Y + 24, label);

    XFlush(dpy);
}

static void bounce(void)
{
    int dx = 17;
    int dy = 13;

    int max_x = sw - WIN_W;
    int max_y = sh - WIN_H;

    if (max_x < 0) max_x = 0;
    if (max_y < 0) max_y = 0;

    for (int i = 0; i < 100; i++) {
        wx += dx;
        wy += dy;

        if (wx <= 0 || wx >= max_x) {
            dx = -dx;
            if (wx < 0) wx = 0;
            if (wx > max_x) wx = max_x;
        }

        if (wy <= 0 || wy >= max_y) {
            dy = -dy;
            if (wy < 0) wy = 0;
            if (wy > max_y) wy = max_y;
        }

        XMoveWindow(dpy, win, wx, wy);
        XFlush(dpy);

        struct timespec delay = {
            .tv_sec = 0,
            .tv_nsec = 20000000L
        };

        nanosleep(&delay, NULL);
    }
}

int main(void)
{
    dpy = XOpenDisplay(NULL);

    if (!dpy) {
        fprintf(stderr, "OKBounce: cannot open X display\n");
        return 1;
    }

    int screen = DefaultScreen(dpy);
    sw = DisplayWidth(dpy, screen);
    sh = DisplayHeight(dpy, screen);

    bg = WhitePixel(dpy, screen);
    fg = BlackPixel(dpy, screen);
    accent = fg;

    XColor color, exact;
    Colormap cmap = DefaultColormap(dpy, screen);

    if (XAllocNamedColor(dpy, cmap, "#d9ecff",
                         &color, &exact))
        bg = color.pixel;

    if (XAllocNamedColor(dpy, cmap, "#164b80",
                         &color, &exact))
        accent = color.pixel;

    wx = (sw - WIN_W) / 2;
    wy = (sh - WIN_H) / 2;

    win = XCreateSimpleWindow(
        dpy, RootWindow(dpy, screen),
        wx, wy, WIN_W, WIN_H, 1, fg, bg
    );

    XStoreName(dpy, win, "TinyDistro OKBounce");

    XSizeHints hints;
    hints.flags = PMinSize | PMaxSize;
    hints.min_width = hints.max_width = WIN_W;
    hints.min_height = hints.max_height = WIN_H;

    XSetWMNormalHints(dpy, win, &hints);

    Atom wm_delete = XInternAtom(
        dpy, "WM_DELETE_WINDOW", False
    );

    XSetWMProtocols(dpy, win, &wm_delete, 1);

    XSelectInput(dpy, win, ExposureMask | ButtonPressMask);

    gc = XCreateGC(dpy, win, 0, NULL);
    font = XLoadQueryFont(dpy, "fixed");

    if (!font) {
        XFreeGC(dpy, gc);
        XDestroyWindow(dpy, win);
        XCloseDisplay(dpy);
        fprintf(stderr, "OKBounce: cannot load fixed font\n");
        return 1;
    }

    XSetFont(dpy, gc, font->fid);
    XMapWindow(dpy, win);

    XEvent ev;

    for (;;) {
        XNextEvent(dpy, &ev);

        if (ev.type == Expose && ev.xexpose.count == 0) {
            draw();
        }

        if (ev.type == ButtonPress) {
            int x = ev.xbutton.x;
            int y = ev.xbutton.y;

            if (x >= BTN_X && x <= BTN_X + BTN_W &&
                y >= BTN_Y && y <= BTN_Y + BTN_H) {
                bounce();
            }
        }

        if (ev.type == ClientMessage &&
            (Atom)ev.xclient.data.l[0] == wm_delete) {
            break;
        }
    }

    XFreeFont(dpy, font);
    XFreeGC(dpy, gc);
    XDestroyWindow(dpy, win);
    XCloseDisplay(dpy);

    return 0;
}
