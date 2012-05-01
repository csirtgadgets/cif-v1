#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.64])
AC_INIT(cif-rouer-perl, m4_esyscmd_s([git describe --tags]), [ci-framework@googlegroups.com])
AM_INIT_AUTOMAKE

# Checks for programs.
AC_ARG_VAR([PERL],[Perl interpreter command])
AC_PATH_PROG([PERL], [perl], [not found])
if test "$PERL" = 'not found'; then
    AC_MSG_ERROR([cannot use $PACKAGE_NAME without perl])
fi

dnl Defaults paths for installation
AC_PREFIX_DEFAULT([/opt/cif])

AC_CONFIG_FILES([
                 Makefile
])


# Checks for libraries.

## apache stuff
## to be split out in v2?
PKG_CHECK_MODULES([apr],[apr-1 >= 1.4.2])
PKG_CHECK_MODULES([apr_util],[apr-util-1 >= 1.3.9]) 

# Checks for header files.

# Checks for typedefs, structures, and compiler characteristics.

# Checks for library functions.

#dnl CIF_USER
AC_ARG_WITH(user,
    AC_HELP_STRING([--with-user=USER],
        [user the cif scripts will run as (default: cif)]),
    CIF_USER=$withval,
    CIF_USER=cif)
AC_SUBST(CIF_USER)

#dnl CIF_GROUP
AC_ARG_WITH(group,
    AC_HELP_STRING([--with-group=GROUP],
        [group the cif scripts will run as (default: cif)]),
    CIF_GROUP=$withval,
    CIF_GROUP=$CIF_USER
)
AC_SUBST(CIF_GROUP)

AC_OUTPUT
