// Minimal fb0 boot console for KNULLI early boot.
// Draws a ROCKNIX-style fake text console directly to /dev/fb0.
// Build target: initramfs + rootfs.

#include <errno.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#define STATE_PATH "/tmp/knulli-fbboot-line"
#define FB_PATH "/dev/fb0"

struct fbctx {
    int fd;
    uint8_t *mem;
    size_t len;
    struct fb_var_screeninfo var;
    struct fb_fix_screeninfo fix;
    int bpp;
    int bytespp;
    int xres;
    int yres;
    int stride;
};

static const char *font_for(char c) {
    switch (c) {
        case 'A': return "01110\n10001\n10001\n11111\n10001\n10001\n10001";
        case 'B': return "11110\n10001\n10001\n11110\n10001\n10001\n11110";
        case 'C': return "01111\n10000\n10000\n10000\n10000\n10000\n01111";
        case 'D': return "11110\n10001\n10001\n10001\n10001\n10001\n11110";
        case 'E': return "11111\n10000\n10000\n11110\n10000\n10000\n11111";
        case 'F': return "11111\n10000\n10000\n11110\n10000\n10000\n10000";
        case 'G': return "01111\n10000\n10000\n10011\n10001\n10001\n01110";
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
        case '[': return "111\n100\n100\n100\n100\n100\n111";
        case ']': return "111\n001\n001\n001\n001\n001\n111";
        case '+': return "00000\n00100\n00100\n11111\n00100\n00100\n00000";
        case '=': return "00000\n11111\n00000\n11111\n00000\n00000\n00000";
        case '>': return "10000\n01000\n00100\n00010\n00100\n01000\n10000";
        case '<': return "00001\n00010\n00100\n01000\n00100\n00010\n00001";
        case ' ': return "0\n0\n0\n0\n0\n0\n0";
        default:  return "11111\n00001\n00010\n00100\n00000\n00100\n00100"; // '?'
    }
}

static uint32_t make_color(struct fbctx *fb, uint8_t r, uint8_t g, uint8_t b) {
    if (fb->bpp == 16) {
        return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
    }
    return (r << 16) | (g << 8) | b;
}

static void put_pixel(struct fbctx *fb, int x, int y, uint32_t color) {
    if (x < 0 || y < 0 || x >= fb->xres || y >= fb->yres) return;
    size_t off = (size_t)y * fb->stride + (size_t)x * fb->bytespp;
    if (off + fb->bytespp > fb->len) return;
    if (fb->bpp == 16) {
        *(uint16_t *)(fb->mem + off) = (uint16_t)color;
    } else if (fb->bpp == 24) {
        fb->mem[off + 0] = color & 0xff;
        fb->mem[off + 1] = (color >> 8) & 0xff;
        fb->mem[off + 2] = (color >> 16) & 0xff;
    } else {
        *(uint32_t *)(fb->mem + off) = color;
    }
}

static void rect(struct fbctx *fb, int x, int y, int w, int h, uint32_t color) {
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

static void draw_text(struct fbctx *fb, const char *s, int x, int y, int scale, uint32_t color) {
    int cx = x;
    for (const char *cp = s; *cp; cp++) {
        char c = *cp;
        if (c >= 'a' && c <= 'z') c -= 32;
        const char *pat = font_for(c);
        int row = 0, col = 0;
        for (const char *p = pat; ; p++) {
            char ch = *p;
            if (ch == '1') rect(fb, cx + col * scale, y + row * scale, scale, scale, color);
            if (ch == '\n' || ch == 0) { row++; col = 0; if (ch == 0) break; }
            else col++;
        }
        cx += (char_width(pat) + 1) * scale;
        if (cx > fb->xres - 20) break;
    }
}

static void clear_screen(struct fbctx *fb, uint32_t color) {
    rect(fb, 0, 0, fb->xres, fb->yres, color);
}

static int fb_open(struct fbctx *fb) {
    memset(fb, 0, sizeof(*fb));
    for (int i = 0; i < 30; i++) {
        fb->fd = open(FB_PATH, O_RDWR);
        if (fb->fd >= 0) break;
        usleep(100000);
    }
    if (fb->fd < 0) return -1;
    if (ioctl(fb->fd, FBIOGET_VSCREENINFO, &fb->var) < 0) return -1;
    if (ioctl(fb->fd, FBIOGET_FSCREENINFO, &fb->fix) < 0) return -1;
    fb->bpp = fb->var.bits_per_pixel ? fb->var.bits_per_pixel : 32;
    fb->bytespp = fb->bpp / 8;
    if (fb->bytespp <= 0) fb->bytespp = 4;
    fb->xres = fb->var.xres ? fb->var.xres : 640;
    fb->yres = fb->var.yres ? fb->var.yres : 480;
    fb->stride = fb->fix.line_length ? fb->fix.line_length : fb->xres * fb->bytespp;
    fb->len = fb->fix.smem_len ? fb->fix.smem_len : (size_t)fb->stride * fb->yres;
    fb->mem = mmap(NULL, fb->len, PROT_READ | PROT_WRITE, MAP_SHARED, fb->fd, 0);
    if (fb->mem == MAP_FAILED) return -1;
    return 0;
}

static void fb_close(struct fbctx *fb) {
    if (fb->mem && fb->mem != MAP_FAILED) munmap(fb->mem, fb->len);
    if (fb->fd >= 0) close(fb->fd);
}

static int read_line_y(void) {
    FILE *f = fopen(STATE_PATH, "r");
    int y = 190;
    if (f) { if (fscanf(f, "%d", &y) != 1) y = 190; fclose(f); }
    return y;
}

static void write_line_y(int y) {
    mkdir("/tmp", 0755);
    FILE *f = fopen(STATE_PATH, "w");
    if (f) { fprintf(f, "%d\n", y); fclose(f); }
}

static void usage(void) {
    fprintf(stderr, "usage: knulli-fbboot reset [TITLE] | msg TEXT...\n");
}

int main(int argc, char **argv) {
    if (argc < 2) { usage(); return 1; }

    struct fbctx fb;
    if (fb_open(&fb) < 0) return 0; // never break boot

    uint32_t black = make_color(&fb, 0, 0, 0);
    uint32_t white = make_color(&fb, 235, 235, 235);
    uint32_t dim   = make_color(&fb, 145, 145, 145);

    if (strcmp(argv[1], "reset") == 0) {
        const char *title = (argc >= 3) ? argv[2] : "KNULLI-KR";
        unlink(STATE_PATH);
        clear_screen(&fb, black);
        rect(&fb, 22, 24, fb.xres - 44, 3, dim);
        rect(&fb, 22, fb.yres - 30, fb.xres - 44, 3, dim);
        draw_text(&fb, title, 42, 56, 7, white);
        draw_text(&fb, "BOOT CONSOLE", 44, 130, 3, dim);
        draw_text(&fb, "==> LOADING PLEASE WAIT", 44, 160, 3, white);
        write_line_y(210);
    } else if (strcmp(argv[1], "msg") == 0) {
        char msg[160] = {0};
        for (int i = 2; i < argc; i++) {
            if (i > 2) strncat(msg, " ", sizeof(msg) - strlen(msg) - 1);
            strncat(msg, argv[i], sizeof(msg) - strlen(msg) - 1);
        }
        if (!msg[0]) strncpy(msg, "OK", sizeof(msg) - 1);
        int y = read_line_y();
        if (y > fb.yres - 48) {
            rect(&fb, 40, 205, fb.xres - 80, fb.yres - 245, black);
            y = 210;
        }
        char line[192];
        snprintf(line, sizeof(line), "[ OK ] %s", msg);
        draw_text(&fb, line, 44, y, 2, white);
        write_line_y(y + 24);
    }

    msync(fb.mem, fb.len, MS_ASYNC);
    fb_close(&fb);
    return 0;
}
