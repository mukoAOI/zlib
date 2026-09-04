#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

static int test_compress_hello_known(void) {
    static const unsigned char expected[] = {
        0x78, 0x9c, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00,
        0x06, 0x2c, 0x02, 0x15,
    };
    const char input[] = "hello";
    const uLong src_len = (uLong)(sizeof(input) - 1);
    const uLong bound = compressBound(src_len);

    unsigned char *compressed = (unsigned char *)malloc(bound);
    if (compressed == NULL) return 1;

    uLong comp_len = bound;
    if (compress(compressed, &comp_len, (const unsigned char *)input, src_len) != Z_OK) {
        free(compressed);
        return 1;
    }

    const int ok = (comp_len == sizeof(expected)) &&
        (memcmp(compressed, expected, sizeof(expected)) == 0);
    free(compressed);
    return ok ? 0 : 1;
}

static int test_compress_roundtrip(void) {
    const char input[] = "zlib_build smoke test payload";
    const uLong src_len = (uLong)(sizeof(input) - 1);
    const uLong bound = compressBound(src_len);

    unsigned char *compressed = (unsigned char *)malloc(bound);
    unsigned char *decompressed = (unsigned char *)malloc(bound);
    if (compressed == NULL || decompressed == NULL) {
        free(compressed);
        free(decompressed);
        return 1;
    }

    uLong comp_len = bound;
    if (compress(compressed, &comp_len, (const unsigned char *)input, src_len) != Z_OK) {
        free(compressed);
        free(decompressed);
        return 1;
    }

    uLong decomp_len = bound;
    if (uncompress(decompressed, &decomp_len, compressed, comp_len) != Z_OK) {
        free(compressed);
        free(decompressed);
        return 1;
    }

    const int ok = (decomp_len == src_len) && (memcmp(decompressed, input, src_len) == 0);
    free(compressed);
    free(decompressed);
    return ok ? 0 : 1;
}

static int test_gzfile_roundtrip(void) {
    const char input[] = "gzip file smoke test";
    const unsigned src_len = (unsigned)(sizeof(input) - 1);
    const char *path = "zlib_build_smoke_test.gz";

    gzFile out = gzopen(path, "wb");
    if (out == NULL) return 1;
    if (gzwrite(out, input, src_len) != (int)src_len) {
        gzclose(out);
        return 1;
    }
    if (gzclose(out) != Z_OK) return 1;

    gzFile in = gzopen(path, "rb");
    if (in == NULL) return 1;

    char buf[64];
    const int n = gzread(in, buf, (unsigned)sizeof(buf));
    if (n < 0 || (unsigned)n != src_len) {
        gzclose(in);
        remove(path);
        return 1;
    }
    if (memcmp(buf, input, src_len) != 0) {
        gzclose(in);
        remove(path);
        return 1;
    }

    const int ok = (gzclose(in) == Z_OK);
    remove(path);
    return ok ? 0 : 1;
}

int main(void) {
    if (test_compress_hello_known() != 0) {
        fputs("compress('hello') known output failed\n", stderr);
        return 1;
    }
    if (test_compress_roundtrip() != 0) {
        fputs("compress roundtrip failed\n", stderr);
        return 1;
    }
    if (test_gzfile_roundtrip() != 0) {
        fputs("gzFile roundtrip failed\n", stderr);
        return 1;
    }
    return 0;
}
