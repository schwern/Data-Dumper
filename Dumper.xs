#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

static long num_q _((char *s));
static long esc_q _((char *dest, char *src));
static SV *sv_x _((char *str, STRLEN len, I32 n));
static int DD_dump _((SV *val, char *name, long namelen, SV *retval,
		      HV *seenhv, AV *postav, long *levelp, long indent,
		      SV *xpad, SV *pad, SV *apad, SV *sep, long purity));

/* count the number of "'"s and "\"s in string */
static long
num_q(s)
register char *s;
{
    register long ret = 0;
    
    while (*s) {
	if (*s == '\'' || *s == '\\')
	    ++ret;
	++s;
    }
    return ret;
}


/* returns number of chars added to escape "'"s and "\"s in s */
static long
esc_q(d, s)
register char *d;
register char *s;
{
    register int ret = 0;
    
REPEAT:
    while (*s && *s != '\'' && *s != '\\') {
	*d = *s;
	++d; ++s;
    }
    switch (*s) {
    case '\'':
    case '\\':
	*d = '\\';
	++d;
	*d = *s;
	++d; ++s; ++ret;
	goto REPEAT;
    case '\0':
	*d = '\0';
	break;
    }
    return ret;
}

/* makes SV with a repeated string when passed a string */
static SV *
sv_x(str, len, n)
register char *str;
register STRLEN len;
I32 n;
{
    register SV *ret = Nullsv;

    if (n > 0) {
	ret = newSVpv(str, len);
	SvGROW(ret, len*n + 1);
	while (n > 1) {
	    sv_catpvn(ret, str, len);
	    --n;
	}
    }
    return ret;
}

/*
 * This ought to split into smaller functions. (it is one long function since
 * it exactly parallels the perl version, which was one long thing for
 * efficiency raisins.
 */
static int
DD_dump(SV *val, char *name, long namelen, SV *retval, HV *seenhv, AV *postav,
	long *levelp, long indent, SV *xpad, SV *pad, SV *apad, SV *sep, long purity)
{
    char tmpbuf[128];
    I32 i;
    char *c, *r, *realpack, *id = tmpbuf;
    SV **svp;
    SV *sv;
    SV *blesspad = Nullsv;
    SV *ipad;
    SV *ival;
    char *iname;
    long inamelen;
    U32 flags;
    U32 realtype;

    if (!val)
	return 0;

    flags = SvFLAGS(val);
    realtype = SvTYPE(val);
    
    if (SvGMAGICAL(val))
        mg_get(val);
    if (val == &sv_undef || !SvOK(val)) {
	sv_catpvn(retval, "undef", 5);
	return 1;
    }
    if (SvROK(val)) {
	AV *seenentry;

	ival = SvRV(val);
	flags = SvFLAGS(ival);
	realtype = SvTYPE(ival);
        (void) sprintf(id, "0x%lx", (unsigned long)ival);
	i = strlen(id);
	if (SvOBJECT(ival))
	    realpack = HvNAME(SvSTASH(ival));
	else
	    realpack = (char *)0;
	if ((svp = hv_fetch(seenhv, id, i, FALSE)) &&
	    (sv = *svp) && SvROK(sv) &&
	    (seenentry = (AV*)SvRV(sv))) {
	    SV *othername;
	    if ((svp = av_fetch(seenentry, 0, FALSE)) && (othername = *svp)) {
		if (purity && *levelp > 0) {
		    SV *postentry;
		    
		    if (realtype == SVt_PVHV)
			sv_catpvn(retval, "{}", 2);
		    else if (realtype == SVt_PVAV)
			sv_catpvn(retval, "[]", 2);
		    else
			sv_catpvn(retval, "''", 2);      /* wierd mlevel structure */
		    postentry = newSVpv(name, namelen);
		    sv_catpvn(postentry, " = ", 3);
		    sv_catsv(postentry, othername);
		    av_push(postav, postentry);
		}
		else {
		    if (name[0] == '@')
			sv_catpvn(retval, "@{", 2);
		    else if(name[0] == '%') 
			sv_catpvn(retval, "%{", 2);
		    sv_catsv(retval, othername);
		    if (name[0] == '@' || name[0] == '%')
			sv_catpvn(retval, "}", 1);
		}
		return 1;
	    }
	    else {
		warn("ref name not found for %s", id);
		return 0;
	    }
	}
	else {   /* store our name and continue */
	    SV *namesv;
	    if (name[0] == '@' || name[0] == '%') {
		namesv = newSVpv("\\", 1);
		sv_catpvn(namesv, name, namelen);
	    }
	    else
		namesv = newSVpv(name, namelen);
	    seenentry = newAV();
	    av_push(seenentry, namesv);
	    SvREFCNT_inc(val);
	    av_push(seenentry, val);
	    hv_store(seenhv, id, strlen(id), newRV((SV*)seenentry), 0);
	    SvREFCNT_dec(seenentry);
	}
	
	(*levelp)++;
	ipad = sv_x(SvPVX(pad), SvCUR(pad), *levelp);

	if (realpack) {   /* we have a blessed ref */
	    sv_catpvn(retval, "bless( ", 7);
	    if (indent >= 2) {
		blesspad = apad;
		apad = newSVsv(apad);
		sv_catpvn(apad, "       ", 7);
	    }
	}

	if (realtype <= SVt_PVBM || realtype == SVt_PVGV) {  /* scalars */
	    New(0, iname, namelen+2, char);
	    iname[0] = '$';
	    (void)strcpy(iname+1, name);
	    if (realpack) {          /* blessed */ 
		sv_catpvn(retval, "\\($_ = ", 7);
		DD_dump(ival, iname, namelen+1, retval, seenhv, postav,
			levelp,	indent, xpad, pad, apad, sep, purity);
		sv_catpvn(retval, ")", 1);
	    }
	    else {
		sv_catpvn(retval, "\\", 1);
		DD_dump(ival, iname, namelen+1, retval, seenhv, postav,
			levelp,	indent, xpad, pad, apad, sep, purity);
	    }
	    Safefree(iname);
	}
	else if (realtype == SVt_PVAV) {
	    SV *totpad;
	    long ix = 0;
	    long ixmax = av_len((AV *)ival);
	    
	    SV *ixsv = newSViv(0);
	    /* allowing for a 24 char wide array index */
	    iname = New(0, iname, namelen+28, char);
	    (void)strcpy(iname, name);
	    inamelen = namelen;
	    if (name[0] == '@') {
		sv_catpvn(retval, "(", 1);
		iname[0] = '$';
	    }
	    else
		sv_catpvn(retval, "[", 1);
	    if (name[namelen-1] != ']' && name[namelen-1] != '}') {
		iname[inamelen++] = '-'; iname[inamelen++] = '>';
	    }
	    iname[inamelen++] = '['; iname[inamelen] = '\0';
	    totpad = newSVsv(sep);
	    sv_catsv(totpad, xpad);
	    sv_catsv(totpad, apad);

	    for (ix = 0; ix <= ixmax; ++ix) {
		long ilen;
		SV *elem;
		svp = av_fetch((AV*)ival, ix, FALSE);
		if (svp)
		    elem = *svp;
		else
		    elem = &sv_undef;
		
		ilen = inamelen;
		sv_setiv(ixsv, ix);
                (void) sprintf(iname+ilen, "%ld", ix);
		ilen = strlen(iname);
		iname[ilen++] = ']'; iname[ilen] = '\0';
		if (indent >= 3) {
		    sv_catsv(retval, totpad);
		    sv_catsv(retval, ipad);
		    sv_catpvn(retval, "#", 1);
		    sv_catsv(retval, ixsv);
		}
		sv_catsv(retval, totpad);
		sv_catsv(retval, ipad);
		DD_dump(elem, iname, ilen, retval, seenhv, postav,
			levelp,	indent, xpad, pad, apad, sep, purity);
		if (ix < ixmax)
		    sv_catpvn(retval, ",", 1);
	    }
	    if (ixmax >= 0) {
		SV *opad = sv_x(SvPVX(pad), SvCUR(pad), (*levelp)-1);
		sv_catsv(retval, totpad);
		sv_catsv(retval, opad);
		SvREFCNT_dec(opad);
	    }
	    if (name[0] == '@')
		sv_catpvn(retval, ")", 1);
	    else
		sv_catpvn(retval, "]", 1);
	    SvREFCNT_dec(ixsv);
	    SvREFCNT_dec(totpad);
	    Safefree(iname);
	}
	else if (realtype == SVt_PVHV) {
	    SV *totpad, *newapad;
	    SV *iname, *sname;
	    HE *entry;
	    char *key;
	    long klen;
	    SV *hval;
	    
	    iname = newSVpv(name, namelen);
	    if (name[0] == '%') {
		sv_catpvn(retval, "(", 1);
		(SvPVX(iname))[0] = '$';
	    }
	    else
		sv_catpvn(retval, "{", 1);
	    if (name[namelen-1] != ']' && name[namelen-1] != '}') {
		sv_catpvn(iname, "->", 2);
	    }
	    sv_catpvn(iname, "{", 1);
	    totpad = newSVsv(sep);
	    sv_catsv(totpad, xpad);
	    sv_catsv(totpad, apad);
	    
	    (void)hv_iterinit((HV*)ival);
	    i = 0;
	    while ((entry = hv_iternext((HV*)ival)))  {
		char *nkey;
		long nticks = 0;
		
		if (i)
		    sv_catpvn(retval, ",", 1);
		i++;
		key = hv_iterkey(entry, &klen);
		hval = hv_iterval((HV*)ival, entry);

		nticks = num_q(key);
		New(0, nkey, klen+nticks+3, char);
		nkey[0] = '\'';
		++klen;
		if (nticks)
		    klen += esc_q(nkey+1, key);
		else
		    (void)strcpy(nkey+1, key);
		nkey[klen++] = '\'';
		nkey[klen] = '\0';

		sname = newSVsv(iname);
		sv_catpvn(sname, nkey, klen);
		sv_catpvn(sname, "}", 1);

		sv_catsv(retval, totpad);
		sv_catsv(retval, ipad);
		sv_catpvn(retval, nkey, klen);
		sv_catpvn(retval, " => ", 4);
		if (indent >= 2) {
		    char *extra;
		    long elen = 0;
		    newapad = newSVsv(apad);
		    New(0, extra, klen+4+1, char);
		    while (elen < (klen+4))
			extra[elen++] = ' ';
		    extra[elen] = '\0';
		    sv_catpvn(newapad, extra, elen);
		    Safefree(extra);
		}
		else
		    newapad = apad;

		DD_dump(hval, SvPVX(sname), SvCUR(sname), retval, seenhv, postav,
			levelp,	indent, xpad, pad, newapad, sep, purity);
		SvREFCNT_dec(sname);
		Safefree(nkey);
		if (indent >= 2)
		    SvREFCNT_dec(newapad);
	    }
	    if (i) {
		SV *opad = sv_x(SvPVX(pad), SvCUR(pad), *levelp-1);
		sv_catsv(retval, totpad);
		sv_catsv(retval, opad);
		SvREFCNT_dec(opad);
	    }
	    if (name[0] == '%')
		sv_catpvn(retval, ")", 1);
	    else
		sv_catpvn(retval, "}", 1);
	    SvREFCNT_dec(iname);
	    SvREFCNT_dec(totpad);
	}
	else if (realtype == SVt_PVCV) {
            int len;
	    (void) sprintf(tmpbuf, "sub { 'CODE(0x%lx)' }", (unsigned long)ival);
            len = strlen(tmpbuf);
	    sv_catpvn(retval, tmpbuf, len);
	    if (purity)
		warn("encountered CODE ref, using dummy placeholder");
	}
	else if (realtype == SVt_PVGV) {
	}
	else {
	    warn("cannot handle ref type %ld", realtype);
	}

	if (realpack) {  /* free blessed allocs */
	    if (indent >= 2) {
		SvREFCNT_dec(apad);
		apad = blesspad;
	    }
	    sv_catpvn(retval, ", '", 3);
	    sv_catpvn(retval, realpack, strlen(realpack));
	    sv_catpvn(retval, "' )", 3);
	}
	SvREFCNT_dec(ipad);
	(*levelp)--;
	return 1;
    }
    else {
	STRLEN i;
	
	if (SvIOK(val)) {
            int len;
	    i = SvIV(val);
            (void) sprintf(tmpbuf, "%d", i);
            len = strlen(tmpbuf);
	    sv_catpvn(retval, tmpbuf, len);
	    return 1;
	}
	else if (SvOK(val)) {
	    if (realtype == SVt_PVGV) { /* GLOBs can end up with scribbly names */
		c = SvPV(val, i);
		sv_grow(retval, SvCUR(retval)+5+2*i);
		r = SvPVX(retval)+SvCUR(retval);
		r[0] = '*'; r[1] = '{';	r[2] = '\'';
		i += 3;
		i += esc_q(r+3, c+1);
		r[i++] = '\''; r[i++] = '}';
		r[i] = '\0';
	    }
	    else {
		c = SvPV(val, i);
		sv_grow(retval, SvCUR(retval)+3+2*i);
		r = SvPVX(retval)+SvCUR(retval);
		r[0] = '\'';
		++i;
		i += esc_q(r+1, c);
		r[i++] = '\'';
		r[i] = '\0';
	    }
	    SvCUR_set(retval, SvCUR(retval)+i);
	    return 1;
	}
	else {
	    return 0;
	}
    }
}


MODULE = Data::Dumper		PACKAGE = Data::Dumper         PREFIX = Data_Dumper_

#
# This is the exact equivalent of Dump.  Well, almost. The things that are
# different: hash keys are always quoted; GLOBs are always dumped in curlies.
#
# Doesnt leak, as far as I can tell from tests. 
#

void
Data_Dumper_Dumpxs(href, ...)
	SV	*href;
	PROTOTYPE: $;$$
	PPCODE:
	{
	    HV *hv;
	    SV *retval;
	    HV *seenhv = Nullhv;
	    AV *postav, *todumpav, *namesav;
	    long level = 0;
	    long indent, purity, i, imax, postlen;
	    SV **svp;
	    SV *val, *name, *xpad, *pad, *apad, *sep, *tmp, *anonpfx;
	    char tmpbuf[1024];

	    if (!SvROK(href)) {		/* call new to get an object first */
		SV *valarray;
		SV *namearray;

		if (items == 3) {
		    valarray = ST(1);
		    namearray = ST(2);
		}
		else
		    croak("Usage: Data::Dumper::Dumpxs(PACKAGE, VAL_ARY_REF, NAME_ARY_REF)");
		
		ENTER;
		SAVETMPS;
		
		PUSHMARK(sp);
		XPUSHs(href);
		XPUSHs(sv_2mortal(newSVsv(valarray)));
		XPUSHs(sv_2mortal(newSVsv(namearray)));
		PUTBACK;
		i = perl_call_method("new", G_SCALAR);
		SPAGAIN;
		if (i)
		    href = newSVsv(POPs);

		PUTBACK;
		FREETMPS;
		LEAVE;
		(void)sv_2mortal(href);
	    }

	    todumpav = namesav = Nullav;
	    seenhv = Nullhv;
	    val = name = xpad = pad = apad = sep = tmp = anonpfx = &sv_undef;
	    
	    retval = newSVpv("", 0);
	    if (SvROK(href)) {
		hv = (HV*)SvRV((SV*)href);
		if (SvTYPE(hv) == SVt_PVHV) {
		    if ((svp = hv_fetch(hv, "seen", 4, FALSE)) && SvROK(*svp))
			seenhv = (HV*)SvRV(*svp);
		    if ((svp = hv_fetch(hv, "todump", 6, FALSE)) && SvROK(*svp))
			todumpav = (AV*)SvRV(*svp);
		    if ((svp = hv_fetch(hv, "names", 5, FALSE)) && SvROK(*svp))
			namesav = (AV*)SvRV(*svp);
		    if ((svp = hv_fetch(hv, "indent", 6, FALSE)))
			indent = SvIV(*svp);
		    if ((svp = hv_fetch(hv, "purity", 6, FALSE)))
			purity = SvIV(*svp);
		    if ((svp = hv_fetch(hv, "xpad", 4, FALSE)))
			xpad = *svp;
		    if ((svp = hv_fetch(hv, "pad", 3, FALSE)))
			pad = *svp;
		    if ((svp = hv_fetch(hv, "apad", 4, FALSE)))
			apad = *svp;
		    if ((svp = hv_fetch(hv, "sep", 3, FALSE)))
			sep = *svp;
		    if ((svp = hv_fetch(hv, "anonpfx", 7, FALSE)))
			anonpfx = *svp;
		    postav = newAV();

		    if (todumpav)
			imax = av_len(todumpav);
		    else
			imax = -1;
		    for (i = 0; i <= imax; ++i) {
			av_clear(postav);
			if ((svp = av_fetch(todumpav, i, FALSE)))
			    val = *svp;
			else
			    val = &sv_undef;
			if ((svp = av_fetch(namesav, i, TRUE)))
			    name = *svp;
			else
			    name = &sv_undef;
			
			if (SvOK(name)) {
			    if ((SvPVX(name))[0] == '*' && SvROK(val)) {
				switch (SvTYPE(SvRV(val))) {
				case SVt_PVAV:
				    (SvPVX(name))[0] = '@';
				    break;
				case SVt_PVHV:
				    (SvPVX(name))[0] = '%';
				    break;
				default:
				    (SvPVX(name))[0] = '$';
				    break;
				}
			    }
			    else if ((SvPVX(name))[0] != '$')
				sv_insert(name, 0, 0, "$", 1);
			}
			else {
			    int nchars = 0;
			    sv_setpvn(name, "$", 1);
			    sv_catsv(name, anonpfx);
			    (void) sprintf(tmpbuf, "%ld", i+1);
                            nchars = strlen(tmpbuf);
			    sv_catpvn(name, tmpbuf, nchars);
			}
			if (indent >= 2)
			    apad = sv_x(" ", 1, SvCUR(name)+3);
			sv_catsv(retval, xpad);
			sv_catsv(retval, name);
			sv_catpvn(retval, " = ", 3);
			DD_dump(val, SvPVX(name), SvCUR(name), retval, seenhv, postav,
				&level, indent, xpad, pad, apad, sep, purity);
			sv_catpvn(retval, ";", 1);
			sv_catsv(retval, sep);
			if ((postlen = av_len(postav)) >= 0) {
			    long i;
			    
			    sv_catsv(retval, xpad);
			    for (i = 0; i <= postlen; ++i) {
				SV *elem;
				svp = av_fetch(postav, i, FALSE);
				if (svp && (elem = *svp)) {
				    sv_catsv(retval, elem);
				    if (i < postlen) {
					sv_catpvn(retval, ";", 1);
					sv_catsv(retval, sep);
					sv_catsv(retval, xpad);
				    }
				}
			    }
			    sv_catpvn(retval, ";", 1);
			    sv_catsv(retval, sep);
			}
			    
			if (indent >= 2)
			    SvREFCNT_dec(apad);
		    }
		    SvREFCNT_dec(postav);
		}
	    }
	    XPUSHs(sv_2mortal(retval));
	}

    
