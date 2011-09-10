#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#define NEED_sv_2pv_flags
#include "ppport.h"

static const U8 utf8_sequence_len[0x100] = {
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0x00-0x0F */
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0x10-0x1F */
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0x20-0x2F */
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0x30-0x3F */
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0x40-0x4F */
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0x50-0x5F */
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0x60-0x6F */
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0x70-0x7F */
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, /* 0x80-0x8F */
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, /* 0x90-0x9F */
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, /* 0xA0-0xAF */
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, /* 0xB0-0xBF */
    0,0,2,2,2,2,2,2,2,2,2,2,2,2,2,2, /* 0xC0-0xCF */
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, /* 0xD0-0xDF */
    3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3, /* 0xE0-0xEF */
    4,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0, /* 0xF0-0xFF */
};

static const U8 utf8_sequence_skip_len[0x100] = {
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0x00-0x0F */
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0x10-0x1F */
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0x20-0x2F */
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0x30-0x3F */
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0x40-0x4F */
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0x50-0x5F */
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0x60-0x6F */
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0x70-0x7F */
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0x80-0x8F */
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0x90-0x9F */
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0xA0-0xAF */
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0xB0-0xBF */
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, /* 0xC0-0xCF */
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, /* 0xD0-0xDF */
    3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3, /* 0xE0-0xEF */
    4,4,4,4,4,4,4,4,5,5,5,5,6,6,1,1, /* 0xF0-0xFF */
};

static STRLEN
utf8_check(const U8 *s, const STRLEN len) {
    const U8 *p = s;
    const U8 *e = s + len;
    U8 n, i;
    U32 v;

    while (p < e - 4) {
        while (p < e - 4 && *p < 0x80)
            p++;

        n = utf8_sequence_len[*p];

      check:
        for (i = 1; i < n; i++)
            if ((p[i] & 0xC0) != 0x80)
                goto done;

        switch (n) {
            case 0:
                goto done;
            case 3:
                v = ((UV)(p[0] & 0x0F) << 12)
                  | ((UV)(p[1] & 0x3F) <<  6)
                  | ((UV)(p[2] & 0x3F));
                if (v < 0x800 || (v & 0xF800) == 0xD800)
                    goto done;
                /* Non-characters U+FDD0..U+FDEF, U+FFFE and U+FFFF */
                if (v >= 0xFDD0 && (v <= 0xFDEF || (v & 0xFFFE) == 0xFFFE))
                    goto done;
                break;
            case 4:
                v = ((UV)(p[0] & 0x07) << 18)
                  | ((UV)(p[1] & 0x3F) << 12)
                  | ((UV)(p[2] & 0x3F) <<  6)
                  | ((UV)(p[3] & 0x3F));
                if (v < 0x10000 || v > 0x10FFFF)
                    goto done;
                /* Non-characters U+nFFFE and U+nFFFF on plane 1-16 */
                if ((v & 0xFFFE) == 0xFFFE)
                    goto done;
                break;
        }
        p += n;
    }
    if (p < e && p + (n = utf8_sequence_len[*p]) <= e)
        goto check;
  done:
    return p - s;
}

static STRLEN
utf8_unpack(const U8 *s, const STRLEN len, UV *usv) {
    const STRLEN n = utf8_sequence_len[*s];
    STRLEN i;

    if (n > len)
        return 0;

    for (i = 1; i < n; i++)
        if ((s[i] & 0xC0) != 0x80)
            return 0;

    switch (n) {
        case 1:
            *usv = (UV)s[0];
            break;
        case 2:
            *usv = ((UV)(s[0] & 0x1F) << 6)
                 | ((UV)(s[1] & 0x3F));
            break;
        case 3:
            *usv = ((UV)(s[0] & 0x0F) << 12)
                 | ((UV)(s[1] & 0x3F) <<  6)
                 | ((UV)(s[2] & 0x3F));
            if (*usv < 0x800 || (*usv & 0xF800) == 0xD800)
                return 0;
            break;
        case 4:
            *usv = ((UV)(s[0] & 0x07) << 18)
                 | ((UV)(s[1] & 0x3F) << 12)
                 | ((UV)(s[2] & 0x3F) <<  6)
                 | ((UV)(s[3] & 0x3F));
            if (*usv < 0x10000 || *usv > 0x10FFFF)
                return 0;
            break;
    }
    return n;
}

static STRLEN
utf8_skip(const U8 *s, const STRLEN len) {
    STRLEN i, n = utf8_sequence_skip_len[*s];

    if (n > len)
        n = len;
    for (i = 1; i < n; i++)
        if ((s[i] & 0xC0) != 0x80)
            break;
    return i;
}

static void
croak_unmappable(pTHX_ const UV cp) {
    const char *fmt;

    if (cp > 0x7FFFFFFF)
        fmt = "Can't map super code point 0x%"UVXf;
    else if (cp > 0x10FFFF)
        fmt = "Can't map restricted code point U-%08"UVXf;
    else if (cp >= 0xFDD0 && (cp <= 0xFDEF || (cp & 0xFFFE) == 0xFFFE))
        fmt = "Can't interchange noncharacter code point U+%"UVXf;
    else if ((cp & 0xF800) == 0xD800)
        fmt = "Can't map surrogate code point U+%"UVXf;
    else
        fmt = "Can't map code point U+%04"UVXf;

    Perl_croak(aTHX_ fmt, cp);
}

static void
croak_illformed(pTHX_ const U8 *s, STRLEN len, const char *enc) {
    static const char *fmt = "Can't decode ill-formed %s octet sequence <%s>";
    static const char *hex = "0123456789ABCDEF";
    char seq[20 * 3 + 4];
    char *d = seq, *dstop = d + sizeof(seq) - 4;

    while (len-- > 0) {
        const U8 c = *s++;
        *d++ = hex[c >> 4];
        *d++ = hex[c & 15];
        if (len) {
            *d++ = ' ';
            if (d == dstop) {
                *d++ = '.', *d++ = '.', *d++ = '.';
                break;
            }
        }
    }
    *d = 0;

    Perl_croak(aTHX_ fmt, enc, seq);
}

MODULE = Unicode::UTF8    PACKAGE = Unicode::UTF8

void
decode_utf8(octets)
    SV *octets
  PREINIT:
    dXSTARG;
    const U8 *src;
    STRLEN len, off;
    SV *dsv;
    UV v;
  PPCODE:
    src = (const U8 *)SvPV_const(octets, len);
    if (SvUTF8(octets)) {
        octets = sv_mortalcopy(octets);
        if (!sv_utf8_downgrade(octets, TRUE))
            croak("Can't decode a wide character string");
        src = (const U8 *)SvPV_const(octets, len);
    }
    off = utf8_check(src, len);
    if (off != len) {
        src += off;
        len -= off;
        if (utf8_unpack(src, len, &v))
            croak_unmappable(aTHX_ v);
        else
            croak_illformed(aTHX_ src, utf8_skip(src, len), "UTF-8");
    }
    dsv = TARG;
    sv_setpvn(dsv, (const char *)src, len);
    SvUTF8_on(dsv);
    PUSHTARG;

void
encode_utf8(string)
    SV *string
  PREINIT:
    dXSTARG;
    const U8 *src;
    STRLEN len;
    SV *dsv = TARG;
  PPCODE:
    src = (const U8 *)SvPV_const(string, len);
    if (!SvUTF8(string)) {
        const U8 *send;
        U8 *d;

        SvUPGRADE(dsv, SVt_PV);
        SvGROW(dsv, len * 2 + 1);
        d    = (U8 *)SvPVX(dsv);
        send = src + len;

        for (; src < send; src++) {
            const U8 c = *src;
            if (c < 0x80)
                *d++ = c;
            else {
                *d++ = (U8)(0xC0 | ((c >>  6) & 0x1F));
                *d++ = (U8)(0x80 | ( c        & 0x3F));
            }
        }
        *d = 0;
        SvCUR_set(dsv, d - (U8 *)SvPVX(dsv));
        SvPOK_only(dsv);
    }
    else {
        UV v;
        STRLEN off = utf8_check(src, len);
        if (off != len) {
            src += off;
            len -= off;
            v = utf8n_to_uvuni(src, len, &off, UTF8_ALLOW_ANYUV|UTF8_CHECK_ONLY);
            if (off == (STRLEN) -1) {
                off = 1;
                if (UTF8_IS_START(*src)) {
                    STRLEN skip = UTF8SKIP(src);
                    if (skip > len)
                        skip = len;
                    while (off < skip && UTF8_IS_CONTINUATION(src[off]))
                        off++;
                }
                croak_illformed(aTHX_ src, off, "UTF-X");
            }
            else
                croak_unmappable(aTHX_ v);
        }
        sv_setpvn(dsv, (const char *)src, len);
    }
    SvUTF8_off(dsv);
    PUSHTARG;


