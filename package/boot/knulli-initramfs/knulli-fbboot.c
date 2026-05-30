// KNULLI fb0 boot UX renderer
// Small static-friendly framebuffer renderer used from initramfs and rootfs.
// Design target: ROCKNIX-like dark screen, bottom-left real KNULLI MOTD, tiny status line.

#include <errno.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#define FB_PATH "/dev/fb0"
#define STATE_PATH "/tmp/knulli-fbboot-state"
#define DEFAULT_MOTD_PATH "/etc/knulli-boot-motd"
#define MAX_MOTD_LINES 14
#define MAX_MOTD_LINE 96

struct fbctx {
    int fd;
    uint8_t *mem;
    size_t len;
    int xres;
    int yres;
    int stride;
    int bpp;
    int bytespp;
    struct fb_var_screeninfo var;
    struct fb_fix_screeninfo fix;
};

static const char *font_for(char c) {
    switch (c) {
        case 'A': return "01110\n10001\n10001\n11111\n10001\n10001\n10001";
        case 'B': return "11110\n10001\n10001\n11110\n10001\n10001\n11110";
        case 'C': return "01111\n10000\n10000\n10000\n10000\n10000\n01111";
        case 'D': return "11110\n10001\n10001\n10001\n10001\n10001\n11110";
        case 'E': return "11111\n10000\n10000\n11110\n10000\n10000\n11111";
        case 'F': return "11111\n10000\n10000\n11110\n10000\n10000\n10000";
        case 'G': return "01111\n10000\n10000\n10011\n10001\n10001\n01111";
        case 'H': return "10001\n10001\n10001\n11111\n10001\n10001\n10001";
        case 'I': return "11111\n00100\n00100\n00100\n00100\n00100\n11111";
        case 'J': return "00111\n00010\n00010\n00010\n10010\n10010\n01100";
        case 'K': return "10001\n10010\n10100\n11000\n10100\n10010\n10001";
        case 'L': return "10000\n10000\n10000\n10000\n10000\n10000\n11111";
        case 'M': return "10001\n11011\n10101\n10101\n10001\n10001\n10001";
        case 'N': return "10001\n11001\n10101\n10011\n10001\n10001\n10001";
        case 'O': return "01110\n10001\n10001\n10001\n10001\n10001\n01110";
        case 'P': return "11110\n10001\n10001\n11110\n10000\n10000\n10000";
        case 'Q': return "01110\n10001\n10001\n10001\n10101\n10010\n01101";
        case 'R': return "11110\n10001\n10001\n11110\n10100\n10010\n10001";
        case 'S': return "01111\n10000\n10000\n01110\n00001\n00001\n11110";
        case 'T': return "11111\n00100\n00100\n00100\n00100\n00100\n00100";
        case 'U': return "10001\n10001\n10001\n10001\n10001\n10001\n01110";
        case 'V': return "10001\n10001\n10001\n10001\n10001\n01010\n00100";
        case 'W': return "10001\n10001\n10001\n10101\n10101\n10101\n01010";
        case 'X': return "10001\n10001\n01010\n00100\n01010\n10001\n10001";
        case 'Y': return "10001\n10001\n01010\n00100\n00100\n00100\n00100";
        case 'Z': return "11111\n00001\n00010\n00100\n01000\n10000\n11111";
        case '0': return "01110\n10001\n10011\n10101\n11001\n10001\n01110";
        case '1': return "00100\n01100\n00100\n00100\n00100\n00100\n01110";
        case '2': return "01110\n10001\n00001\n00010\n00100\n01000\n11111";
        case '3': return "11110\n00001\n00001\n01110\n00001\n00001\n11110";
        case '4': return "00010\n00110\n01010\n10010\n11111\n00010\n00010";
        case '5': return "11111\n10000\n10000\n11110\n00001\n00001\n11110";
        case '6': return "01110\n10000\n10000\n11110\n10001\n10001\n01110";
        case '7': return "11111\n00001\n00010\n00100\n01000\n01000\n01000";
        case '8': return "01110\n10001\n10001\n01110\n10001\n10001\n01110";
        case '9': return "01110\n10001\n10001\n01111\n00001\n00001\n01110";
        case '-': return "00000\n00000\n00000\n11111\n00000\n00000\n00000";
        case '_': return "00000\n00000\n00000\n00000\n00000\n00000\n11111";
        case ':': return "000\n010\n010\n000\n010\n010\n000";
        case '.': return "000\n000\n000\n000\n000\n010\n010";
        case '/': return "00001\n00010\n00010\n00100\n01000\n01000\n10000";
        case '\\': return "10000\n01000\n01000\n00100\n00010\n00010\n00001";
        case '|': return "1\n1\n1\n1\n1\n1\n1";
        case '\'': return "010\n010\n100\n000\n000\n000\n000";
        case '[': return "111\n100\n100\n100\n100\n100\n111";
        case ']': return "111\n001\n001\n001\n001\n001\n111";
        case '+': return "00000\n00100\n00100\n11111\n00100\n00100\n00000";
        case '=': return "00000\n11111\n00000\n11111\n00000\n00000\n00000";
        case '>': return "10000\n01000\n00100\n00010\n00100\n01000\n10000";
        case '<': return "00001\n00010\n00100\n01000\n00100\n00010\n00001";
        case ',': return "000\n000\n000\n000\n000\n010\n100";
        case '!': return "010\n010\n010\n010\n010\n000\n010";
        case '(': return "0010\n0100\n1000\n1000\n1000\n0100\n0010";
        case ')': return "0100\n0010\n0001\n0001\n0001\n0010\n0100";
        case ' ': return "0\n0\n0\n0\n0\n0\n0";
        default:  return "00000\n00000\n00000\n00000\n00000\n00000\n00000";
    }
}


static uint32_t make_color(struct fbctx *fb, uint8_t r, uint8_t g, uint8_t b) {
    if (fb->bpp == 16) {
        return (uint32_t)(((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3));
    }
    return ((uint32_t)r << 16) | ((uint32_t)g << 8) | (uint32_t)b;
}

static uint32_t ansi_color(struct fbctx *fb, int code, uint32_t fallback) {
    switch (code) {
        case 30: return make_color(fb, 20, 20, 20);
        case 31: return make_color(fb, 220, 80, 80);
        case 32: return make_color(fb, 90, 220, 130);
        case 33: return make_color(fb, 225, 210, 90);
        case 34: return make_color(fb, 95, 150, 255);
        case 35: return make_color(fb, 210, 100, 230);
        case 36: return make_color(fb, 80, 220, 235);
        case 37: return make_color(fb, 225, 225, 225);
        case 90: return make_color(fb, 120, 120, 120);
        case 91: return make_color(fb, 255, 115, 115);
        case 92: return make_color(fb, 130, 255, 165);
        case 93: return make_color(fb, 255, 235, 130);
        case 94: return make_color(fb, 135, 185, 255);
        case 95: return make_color(fb, 235, 145, 255);
        case 96: return make_color(fb, 125, 245, 255);
        case 97: return make_color(fb, 245, 245, 245);
        default: return fallback;
    }
}

static void put_pixel_raw(struct fbctx *fb, int x, int raw_y, uint32_t color) {
    int virtual_y = fb->var.yres_virtual ? (int)fb->var.yres_virtual : fb->yres;
    if (x < 0 || raw_y < 0 || x >= fb->xres || raw_y >= virtual_y) return;
    size_t off = (size_t)raw_y * (size_t)fb->stride + (size_t)x * (size_t)fb->bytespp;
    if (off + (size_t)fb->bytespp > fb->len) return;
    if (fb->bpp == 16) {
        uint16_t c = (uint16_t)color;
        memcpy(fb->mem + off, &c, sizeof(c));
    } else if (fb->bpp == 24) {
        fb->mem[off + 0] = color & 0xff;
        fb->mem[off + 1] = (color >> 8) & 0xff;
        fb->mem[off + 2] = (color >> 16) & 0xff;
    } else {
        uint32_t c = color;
        memcpy(fb->mem + off, &c, sizeof(c));
    }
}

static void put_pixel(struct fbctx *fb, int x, int y, uint32_t color) {
    if (x < 0 || y < 0 || x >= fb->xres || y >= fb->yres) return;

    // H700 devices commonly expose 640x480 visible and 640x960 virtual fb0.
    // Boot components can pan between pages, so write the same pixel to every
    // visible-sized page.  This prevents stale status text from surviving on
    // the other framebuffer page and reduces late-boot flicker/ghosting.
    int virtual_y = fb->var.yres_virtual ? (int)fb->var.yres_virtual : fb->yres;
    int pages = (fb->yres > 0) ? (virtual_y / fb->yres) : 1;
    if (pages < 1) pages = 1;
    if (pages > 4) pages = 4;

    for (int page = 0; page < pages; page++) {
        int raw_y = y + page * fb->yres;
        put_pixel_raw(fb, x, raw_y, color);
    }
}

static void rect(struct fbctx *fb, int x, int y, int w, int h, uint32_t color) {
    if (w <= 0 || h <= 0) return;
    for (int yy = y; yy < y + h; yy++) {
        for (int xx = x; xx < x + w; xx++) put_pixel(fb, xx, yy, color);
    }
}

static int char_width(const char *pat) {
    int max = 1, cur = 0;
    for (const char *p = pat; *p; p++) {
        if (*p == '\n') { if (cur > max) max = cur; cur = 0; }
        else cur++;
    }
    if (cur > max) max = cur;
    return max;
}

// Text scale is fixed point, 16 == old 1x.  This lets us tune the boot UI
// by about +20% without jumping from 1x straight to 2x.
static int cell_px(int cells, int scale16) {
    int v = (cells * scale16 + 15) / 16;
    return v > 0 ? v : 1;
}


static int parse_sgr(struct fbctx *fb, const char **cpp, uint32_t base, uint32_t *cur) {
    const char *p = *cpp;
    if ((unsigned char)*p != 27 || p[1] != '[') return 0;
    p += 2;
    int any = 0;
    while (*p && *p != 'm') {
        int val = 0;
        int have = 0;
        while (*p >= '0' && *p <= '9') {
            val = val * 10 + (*p - '0');
            p++;
            have = 1;
        }
        if (!have) val = 0;
        if (val == 0) *cur = base;
        else if (val == 1) *cur = make_color(fb, 255, 255, 255);
        else if ((val >= 30 && val <= 37) || (val >= 90 && val <= 97)) *cur = ansi_color(fb, val, *cur);
        any = 1;
        if (*p == ';') p++;
        else if (*p && *p != 'm') p++;
    }
    if (*p == 'm') p++;
    *cpp = p;
    return any;
}

static void draw_char(struct fbctx *fb, char c, int x, int y, int scale16, uint32_t color) {
    if (c >= 'a' && c <= 'z') c -= 32;
    const char *pat = font_for(c);
    int row = 0, col = 0;
    for (const char *p = pat; ; p++) {
        char ch = *p;
        if (ch == '1') {
            int x0 = x + cell_px(col, scale16);
            int y0 = y + cell_px(row, scale16);
            int x1 = x + cell_px(col + 1, scale16);
            int y1 = y + cell_px(row + 1, scale16);
            rect(fb, x0, y0, x1 - x0, y1 - y0, color);
        }
        if (ch == '\n' || ch == 0) { row++; col = 0; if (ch == 0) break; }
        else col++;
    }
}
static int visible_char_width(char c, int scale16) {
    if (c >= 'a' && c <= 'z') c -= 32;
    return cell_px(char_width(font_for(c)) + 1, scale16);
}

static void draw_text_ansi(struct fbctx *fb, const char *s, int x, int y, int scale, uint32_t base, int max_width) {
    int cx = x;
    uint32_t cur = base;
    for (const char *cp = s; *cp; ) {
        if (parse_sgr(fb, &cp, base, &cur)) continue;
        unsigned char ch = (unsigned char)*cp++;
        if (ch == '\r' || ch == '\n' || ch == '\t') ch = ' ';
        if (ch < 32 || ch > 126) ch = ' ';
        int cw = visible_char_width((char)ch, scale);
        if (max_width > 0 && cx + cw > x + max_width) break;
        draw_char(fb, (char)ch, cx, y, scale, cur);
        cx += cw;
        if (cx > fb->xres - 4) break;
    }
}

static void clear_screen(struct fbctx *fb, uint32_t color) {
    rect(fb, 0, 0, fb->xres, fb->yres, color);
}

static int fb_open(struct fbctx *fb) {
    memset(fb, 0, sizeof(*fb));
    fb->fd = -1;
    for (int i = 0; i < 40; i++) {
        fb->fd = open(FB_PATH, O_RDWR);
        if (fb->fd >= 0) break;
        usleep(100000);
    }
    if (fb->fd < 0) return -1;
    if (ioctl(fb->fd, FBIOGET_VSCREENINFO, &fb->var) < 0) return -1;
    if (ioctl(fb->fd, FBIOGET_FSCREENINFO, &fb->fix) < 0) return -1;
    fb->bpp = fb->var.bits_per_pixel ? (int)fb->var.bits_per_pixel : 32;
    fb->bytespp = fb->bpp / 8;
    if (fb->bytespp <= 0) fb->bytespp = 4;
    fb->xres = fb->var.xres ? (int)fb->var.xres : 640;
    fb->yres = fb->var.yres ? (int)fb->var.yres : 480;
    fb->stride = fb->fix.line_length ? (int)fb->fix.line_length : fb->xres * fb->bytespp;
    fb->len = fb->fix.smem_len ? (size_t)fb->fix.smem_len : (size_t)fb->stride * (size_t)fb->yres;
    fb->mem = mmap(NULL, fb->len, PROT_READ | PROT_WRITE, MAP_SHARED, fb->fd, 0);
    if (fb->mem == MAP_FAILED) return -1;
    return 0;
}

static void fb_close(struct fbctx *fb) {
    if (fb->mem && fb->mem != MAP_FAILED) munmap(fb->mem, fb->len);
    if (fb->fd >= 0) close(fb->fd);
}

static void save_status(const char *msg) {
    mkdir("/tmp", 0755);
    FILE *f = fopen(STATE_PATH, "w");
    if (f) { fprintf(f, "%s\n", msg ? msg : ""); fclose(f); }
}

static void strip_to_plain(char *s) {
    char *d = s;
    for (char *p = s; *p; p++) {
        unsigned char ch = (unsigned char)*p;
        if (ch == 27) {
            p++;
            if (*p == '[') while (*p && *p != 'm') p++;
            if (!*p) break;
            continue;
        }
        if (ch == '\r' || ch == '\n' || ch == '\t') ch = ' ';
        if (ch >= 32 && ch <= 126) *d++ = (char)ch;
    }
    *d = 0;
    while (d > s && d[-1] == ' ') { d--; *d = 0; }
}

static int text_width_plain_px(const char *s, int scale) {
    int w = 0;
    uint32_t dummy = 0;
    (void)dummy;
    for (const char *cp = s; *cp; ) {
        if ((unsigned char)*cp == 27 && cp[1] == '[') {
            cp += 2;
            while (*cp && *cp != 'm') cp++;
            if (*cp == 'm') cp++;
            continue;
        }
        unsigned char ch = (unsigned char)*cp++;
        if (ch < 32 || ch > 126) ch = ' ';
        w += visible_char_width((char)ch, scale);
    }
    return w;
}

static void clear_status_area(struct fbctx *fb) {
    uint32_t black = make_color(fb, 0, 0, 0);
    int margin = fb->xres < 520 ? 10 : 28;
    int scale = 28; // v11: about 20% larger than v10 status text
    int h = cell_px(7, scale) + 14;
    int y = fb->yres - margin - cell_px(7, scale);
    if (y < margin) y = fb->yres - 24;
    rect(fb, margin, y - 6, fb->xres - margin * 2, h, black);
    save_status("");
}

static void draw_status_at(struct fbctx *fb, const char *status, int clear_area, int y, int scale) {
    uint32_t white = make_color(fb, 235, 235, 235);
    int margin = fb->xres < 520 ? 10 : 28;
    if (scale <= 0) scale = 23;
    if (y < margin) y = fb->yres - margin - cell_px(7, scale);
    if (y < margin) y = fb->yres - 24;

    // ROCKNIX-style: no divider/border lines. Keep the lower status area clean
    // and update only the message row.
    if (clear_area) clear_status_area(fb);

    char sbuf[192];
    snprintf(sbuf, sizeof(sbuf), "[36m>>[0m %s", status && status[0] ? status : "Loading, please wait...");
    draw_text_ansi(fb, sbuf, margin, y, scale, white, fb->xres - margin * 2);

    char plain[192];
    snprintf(plain, sizeof(plain), ">> %s", status && status[0] ? status : "Loading, please wait...");
    strip_to_plain(plain);
    save_status(plain);
}

static void draw_status(struct fbctx *fb, const char *status, int clear_area) {
    int margin = fb->xres < 520 ? 10 : 28;
    int scale = 28; // v11: about 20% larger than v10 status text
    int y = fb->yres - margin - cell_px(7, scale);
    draw_status_at(fb, status, clear_area, y, scale);
}

static int read_motd_file(const char *path, char lines[MAX_MOTD_LINES][MAX_MOTD_LINE]) {
    FILE *f = fopen(path, "r");
    if (!f) return 0;
    int n = 0;
    char buf[512];
    while (fgets(buf, sizeof(buf), f) && n < MAX_MOTD_LINES) {
        char *e = buf + strlen(buf);
        while (e > buf && (e[-1] == '\n' || e[-1] == '\r')) { *--e = 0; }
        // Skip empty lines. The boot screen intentionally keeps only compact info.
        char plain[512];
        strncpy(plain, buf, sizeof(plain)-1);
        plain[sizeof(plain)-1] = 0;
        strip_to_plain(plain);
        if (!plain[0]) continue;
        strncpy(lines[n], buf, MAX_MOTD_LINE - 1);
        lines[n][MAX_MOTD_LINE - 1] = 0;
        n++;
    }
    fclose(f);
    return n;
}

static int looks_like_info_line(const char *s) {
    char plain[256];
    if (!s) return 0;
    strncpy(plain, s, sizeof(plain) - 1);
    plain[sizeof(plain) - 1] = 0;
    strip_to_plain(plain);
    char *p = plain;
    while (*p == ' ' || *p == '	') p++;
    if (strncasecmp(p, "MODEL", 5) == 0) return 1;
    if (strncasecmp(p, "BUILD", 5) == 0) return 1;
    if (strncasecmp(p, "OS VERSION", 10) == 0) return 1;
    return 0;
}


static void draw_diag(struct fbctx *fb, int x0, int y0, int x1, int y1, int stroke, uint32_t color) {
    int dx = x1 > x0 ? x1 - x0 : x0 - x1;
    int sx = x0 < x1 ? 1 : -1;
    int dy = y1 > y0 ? y0 - y1 : y1 - y0;
    int sy = y0 < y1 ? 1 : -1;
    int err = dx + dy;
    int x = x0, y = y0;
    if (stroke < 1) stroke = 1;
    for (;;) {
        rect(fb, x - stroke / 2, y - stroke / 2, stroke, stroke, color);
        if (x == x1 && y == y1) break;
        int e2 = 2 * err;
        if (e2 >= dy) { err += dy; x += sx; }
        if (e2 <= dx) { err += dx; y += sy; }
    }
}

static void draw_ascii_art_cell(struct fbctx *fb, char c, int x, int y, int cw, int ch, int stroke, uint32_t color) {
    if (c == ' ') return;
    if (stroke < 1) stroke = 1;
    int cx = x + cw / 2;
    switch (c) {
        case '_':
            rect(fb, x, y + ch - stroke, cw, stroke, color);
            break;
        case '-':
            rect(fb, x, y + ch / 2, cw, stroke, color);
            break;
        case '|':
            rect(fb, cx - stroke / 2, y, stroke, ch, color);
            break;
        case '/':
            draw_diag(fb, x + cw - 1, y, x, y + ch - 1, stroke, color);
            break;
        case '\\':
            draw_diag(fb, x, y, x + cw - 1, y + ch - 1, stroke, color);
            break;
        case '\'':
            rect(fb, cx - stroke / 2, y, stroke, ch / 2 > stroke ? ch / 2 : stroke, color);
            break;
        case '.':
            rect(fb, cx - stroke / 2, y + ch - stroke, stroke, stroke, color);
            break;
        default:
            rect(fb, cx - stroke / 2, y + ch / 2 - stroke / 2, stroke, stroke, color);
            break;
    }
}

static void draw_ascii_art_line(struct fbctx *fb, const char *s, int x, int y, int cw, int ch, int stroke, uint32_t color, int max_width) {
    int cx = x;
    for (const char *p = s; *p; p++) {
        unsigned char c = (unsigned char)*p;
        if (c == '\r' || c == '\n' || c == '\t') c = ' ';
        if (c < 32 || c > 126) c = ' ';
        if (max_width > 0 && cx + cw > x + max_width) break;
        draw_ascii_art_cell(fb, (char)c, cx, y, cw, ch, stroke, color);
        cx += cw;
        if (cx > fb->xres - 2) break;
    }
}

static void draw_compact_screen(struct fbctx *fb, char lines[MAX_MOTD_LINES][MAX_MOTD_LINE], int n) {
    uint32_t black = make_color(fb, 0, 0, 0);
    uint32_t white = make_color(fb, 238, 238, 238);

    int margin = fb->xres < 520 ? 12 : 30;

    // v11 tuning:
    // - The KNULLI MOTD logo is terminal ASCII art.  A square cell stretches it
    //   horizontally, so render logo cells with a terminal-like narrow width and
    //   taller height.
    // - Bump MODEL/BUILD/status text about 20% from v10.
    int info_scale = 28;
    int status_scale = 28;
    int info_line_h = cell_px(7, info_scale) + 5;
    int status_line_h = cell_px(7, status_scale);

    int logo_cw = fb->xres < 520 ? 5 : 6;
    int logo_ch = fb->xres < 520 ? 9 : 11;
    int logo_stroke = fb->xres < 520 ? 1 : 2;

    int first_info = n;
    for (int i = 0; i < n; i++) {
        if (looks_like_info_line(lines[i])) { first_info = i; break; }
    }

    int logo_lines = first_info;
    if (logo_lines > 9) logo_lines = 9;
    int info_lines = n - first_info;
    if (info_lines > 2) info_lines = 2;
    if (info_lines < 0) info_lines = 0;

    // Lay out top-to-bottom as one compact lower-left block. Earlier versions
    // anchored each section separately to the bottom, which could push MODEL /
    // BUILD into an awkward or invisible area on some fb0 timings.
    int gap_logo_info = 6;
    int gap_info_status = 4; // keep MODEL/BUILD close to the lower progress line
    int title_scale_fallback = fb->xres < 420 ? 46 : 70;
    int logo_h = logo_lines > 0 ? logo_lines * logo_ch : cell_px(7, title_scale_fallback);
    int info_h = info_lines * info_line_h;
    int block_h = logo_h + gap_logo_info + info_h + gap_info_status + status_line_h;
    int logo_y = fb->yres - margin - block_h;
    if (logo_y < margin) logo_y = margin;
    int info_y = logo_y + logo_h + gap_logo_info;
    int status_y = info_y + info_h + gap_info_status;

    clear_screen(fb, black);

    if (logo_lines > 0) {
        for (int i = 0; i < logo_lines; i++) {
            draw_ascii_art_line(fb, lines[i], margin, logo_y + i * logo_ch,
                                logo_cw, logo_ch, logo_stroke, white,
                                fb->xres - margin * 2);
        }
    } else {
        draw_text_ansi(fb, "KNULLI", margin, logo_y, title_scale_fallback, white, fb->xres - margin * 2);
    }

    for (int i = 0; i < info_lines; i++) {
        // Keep MODEL / BUILD bright enough to survive dim panels and camera exposure.
        draw_text_ansi(fb, lines[first_info + i], margin + 1, info_y + i * info_line_h,
                       info_scale, white, fb->xres - margin * 2);
    }

    draw_status_at(fb, "Loading, please wait...", 0, status_y, status_scale);
}

static void draw_shell(struct fbctx *fb, const char *title, const char *status, int clear) {
    uint32_t black = make_color(fb, 0, 0, 0);
    uint32_t white = make_color(fb, 230, 230, 230);
    uint32_t dim   = make_color(fb, 210, 210, 210);

    int margin = fb->xres < 520 ? 12 : 30;
    int title_scale = fb->xres < 420 ? 54 : 84; // v11: fallback title only
    int info_scale = 28;                         // v11: about 20% larger
    int title_h = cell_px(7, title_scale);
    int block_h = title_h + 8 + cell_px(7, info_scale) + 16 + cell_px(7, info_scale) + 16;
    int y = fb->yres - margin - block_h;
    if (y < margin) y = margin;

    if (clear) {
        clear_screen(fb, black);
        draw_text_ansi(fb, title && title[0] ? title : "KNULLI", margin, y, title_scale, white, fb->xres - margin * 2);
        draw_text_ansi(fb, "\033[36mMODEL:\033[0m KNULLI", margin + 1, y + title_h + 8, info_scale, white, fb->xres - margin * 2);
        draw_text_ansi(fb, "\033[36mBUILD:\033[0m BOOTING", margin + 1, y + title_h + 8 + cell_px(7, info_scale) + 5, info_scale, white, fb->xres - margin * 2);
    }
    draw_status(fb, status, !clear);
}

static void draw_motd_file(struct fbctx *fb, const char *path) {
    char lines[MAX_MOTD_LINES][MAX_MOTD_LINE];
    memset(lines, 0, sizeof(lines));
    int n = read_motd_file(path, lines);
    if (n <= 0) {
        draw_shell(fb, "KNULLI", "Loading, please wait...", 1);
        return;
    }
    draw_compact_screen(fb, lines, n);
}

static int readable_nonempty(const char *path) {
    struct stat st;
    return path && stat(path, &st) == 0 && st.st_size > 0;
}

static void usage(void) {
    fprintf(stderr, "usage: knulli-fbboot reset [TITLE] | msg TEXT... | file /path/to/motd | clear-status\n");
}

int main(int argc, char **argv) {
    if (argc < 2) { usage(); return 1; }

    struct fbctx fb;
    if (fb_open(&fb) < 0) return 0; // never break boot

    if (strcmp(argv[1], "reset") == 0) {
        if (readable_nonempty(DEFAULT_MOTD_PATH)) {
            draw_motd_file(&fb, DEFAULT_MOTD_PATH);
        } else {
            const char *title = (argc >= 3) ? argv[2] : "KNULLI";
            draw_shell(&fb, title, "Loading, please wait...", 1);
        }
    } else if (strcmp(argv[1], "msg") == 0) {
        char msg[160] = {0};
        for (int i = 2; i < argc; i++) {
            if (i > 2) strncat(msg, " ", sizeof(msg) - strlen(msg) - 1);
            strncat(msg, argv[i], sizeof(msg) - strlen(msg) - 1);
        }
        if (!msg[0]) strncpy(msg, "Loading, please wait...", sizeof(msg) - 1);
        draw_status(&fb, msg, 1);
    } else if (strcmp(argv[1], "file") == 0) {
        const char *path = (argc >= 3) ? argv[2] : "/tmp/knulli-fbboot.motd";
        draw_motd_file(&fb, path);
    } else if (strcmp(argv[1], "clear-status") == 0 || strcmp(argv[1], "done") == 0) {
        clear_status_area(&fb);
    } else {
        usage();
    }

    if (fb.mem && fb.mem != MAP_FAILED) msync(fb.mem, fb.len, MS_ASYNC);
    fb_close(&fb);
    return 0;
}
