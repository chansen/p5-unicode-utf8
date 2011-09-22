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
    STRLEN i, n = utf8_sequence_len[*s];

    if (n < 1 || len < 2)
        return 1;
    switch (s[0]) {
        case 0xE0: if ((s[1] & 0xE0) == 0x80) return 1; break;
        case 0xED: if ((s[1] & 0xE0) == 0xA0) return 1; break;
        case 0xF0: if ((s[1] & 0xF0) == 0x80) return 1; break;
        case 0xF4: if ((s[1] & 0xF0) != 0x80) return 1; break;
    }
    if (n > len)
        n = len;
    for (i = 1; i < n; i++)
        if ((s[i] & 0xC0) != 0x80)
            break;
    return i;
}

static void
report_unmappable(pTHX_ const UV cp, const STRLEN pos) {
    const char *fmt;

    if (cp > 0x10FFFF)
        fmt = "Can't represent super code point \\x{%"UVXf"} at position %"UVuf" in UTF-8 encoding form";
    else if (cp >= 0xFDD0 && (cp <= 0xFDEF || (cp & 0xFFFE) == 0xFFFE))
        fmt = "Can't interchange noncharacter code point U+%"UVXf" at position %"UVuf;
    else if ((cp & 0xF800) == 0xD800)
        fmt = "Can't represent surrogate code point U+%"UVXf" at position %"UVuf" in UTF-8 encoding form";
    else
        fmt = "Can't represent code point U+%04"UVXf" at position %"UVuf" in UTF-8 encoding form";

    Perl_warner(aTHX_ packWARN(WARN_UTF8), fmt, cp, (UV)pos);
}

static void
report_illformed(pTHX_ const U8 *s, STRLEN len, const char *enc, STRLEN pos, const bool fatal) {
    static const char *fmt = "Can't decode ill-formed %s octet sequence <%s> in position %"UVuf;
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

    if (fatal)
        Perl_croak(aTHX_ fmt, enc, seq, (UV)pos);
    else
        Perl_warner(aTHX_ packWARN(WARN_UTF8), fmt, enc, seq, (UV)pos);
}

static void
decode_utf8(pTHX_ const U8 *src, STRLEN len, STRLEN off, SV *dsv) {
    const bool do_warn = ckWARN(WARN_UTF8);
    STRLEN pos = 0;
    STRLEN skip;
    UV v;

    SvUPGRADE(dsv, SVt_PV);
    SvCUR_set(dsv, 0);

    do {
        src += off;
        len -= off;
        pos += off;

        skip = utf8_skip(src, len);
        if (do_warn) {
            if (utf8_unpack(src, skip, &v))
                report_unmappable(aTHX_ v, pos);
            else
                report_illformed(aTHX_ src, skip, "UTF-8", pos, FALSE);
        }

        sv_catpvn(dsv, (const char *)src - off, off);
        sv_catpvn(dsv,"\xEF\xBF\xBD", 3);

        src += skip;
        len -= skip;
        pos += skip;

        off = utf8_check(src, len);
        if (off == len) {
            sv_catpvn(dsv, (const char *)src, off);
            break;
        }
    } while (len);
}

static void
encode_utf8(pTHX_ const U8 *src, STRLEN len, STRLEN off, SV *dsv) {
    const bool do_warn = ckWARN(WARN_UTF8);
    STRLEN pos = 0;
    STRLEN skip;
    UV v;

    SvUPGRADE(dsv, SVt_PV);
    SvCUR_set(dsv, 0);

    do {
        src += off;
        len -= off;
        pos += utf8_length(aTHX_ src - off, src);

        v = utf8n_to_uvuni(src, len, &skip, UTF8_ALLOW_ANYUV|UTF8_CHECK_ONLY);
        if (skip == (STRLEN) -1) {
            skip = 1;
            if (UTF8_IS_START(*src)) {
                STRLEN n = UTF8SKIP(src);
                if (n > len)
                    n = len;
                while (skip < n && UTF8_IS_CONTINUATION(src[skip]))
                    skip++;
            }
            report_illformed(aTHX_ src, skip, "UTF-X", pos, TRUE);
        }
        if (do_warn)
            report_unmappable(aTHX_ v, pos);

        sv_catpvn(dsv, (const char *)src - off, off);
        sv_catpvn(dsv,"\xEF\xBF\xBD", 3);

        src += skip;
        len -= skip;
        pos += 1;

        off = utf8_check(src, len);
        if (off == len) {
            sv_catpvn(dsv, (const char *)src, off);
            break;
        }
    } while (len);
}

MODULE = Unicode::UTF8    PACKAGE = Unicode::UTF8

void
decode_utf8(octets)
    SV *octets
  PREINIT:
    dXSTARG;
    const U8 *src;
    STRLEN len, off;
  PPCODE:
    src = (const U8 *)SvPV_const(octets, len);
    if (SvUTF8(octets)) {
        octets = sv_mortalcopy(octets);
        if (!sv_utf8_downgrade(octets, TRUE))
            croak("Can't decode a wide character string");
        src = (const U8 *)SvPV_const(octets, len);
    }
    off = utf8_check(src, len);
    if (off == len)
        sv_setpvn(TARG, (const char *)src, len);
    else
        decode_utf8(aTHX_ src, len, off, TARG);

    SvUTF8_on(TARG);
    PUSHTARG;

void
encode_utf8(string)
    SV *string
  PREINIT:
    dXSTARG;
    const U8 *src;
    STRLEN len;
  PPCODE:
    src = (const U8 *)SvPV_const(string, len);
    if (!SvUTF8(string)) {
        const U8 *send;
        U8 *d;

        SvUPGRADE(TARG, SVt_PV);
        SvGROW(TARG, len * 2 + 1);
        d    = (U8 *)SvPVX(TARG);
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
        SvCUR_set(TARG, d - (U8 *)SvPVX(TARG));
        SvPOK_only(TARG);
        SvTAINT(TARG);
    }
    else {
        STRLEN off = utf8_check(src, len);
        if (off == len)
            sv_setpvn(TARG, (const char *)src, len);
        else
            encode_utf8(aTHX_ src, len, off, TARG);
    }
    SvUTF8_off(TARG);
    PUSHTARG;


