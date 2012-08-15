#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.64])
AC_INIT(cif-smrt, m4_esyscmd_s([git describe --tags]), [ci-framework@googlegroups.com])
AM_INIT_AUTOMAKE

# Checks for programs.
AC_ARG_VAR([PERL],[Perl interpreter command])
AC_PATH_PROG([PERL], [perl], [not found])
if test "$PERL" = 'not found'; then
    AC_MSG_ERROR([cannot use $PACKAGE_NAME without perl])
fi

AC_ARG_VAR([PSQL],[Postgres psql command])
AC_PATH_PROG([PSQL],[psql],[not found])
if test "$PSQL" = 'not found'; then
    AC_MSG_ERROR([cannot use $PACKAGE_NAME without postgres psql])
fi

AC_ARG_VAR([PGDUMP],[Postgres pg_dump command])
AC_PATH_PROG([PGDUMP],[pg_dump],[not found])
if test "$PGDUMP" = 'not found'; then
    AC_MSG_ERROR([cannot use $PACKAGE_NAME without postgres pg_dump])
fi

dnl Defaults paths for installation
AC_PREFIX_DEFAULT([/opt/cif])

AC_CONFIG_FILES([
                 Makefile
])


# Checks for libraries.

## ZeroMQ specific -- coming in beta2
##PKG_CHECK_MODULES([libzmq],[libzmq >= 2.1.11])
##PKG_CHECK_MODULES([libzmq],[libzmq < 2.2])

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
