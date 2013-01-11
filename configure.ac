#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.64])
AC_INIT(cif-router, m4_esyscmd_s([git describe --tags]), [ci-framework@googlegroups.com])
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

dnl Defaults paths for installation
AC_PREFIX_DEFAULT([/opt/cif])

AC_CONFIG_FILES([
                 Makefile
])


# Checks for libraries.

## apache stuff
## to be split out in v2?
#PKG_CHECK_MODULES([apr],[apr-1 >= 1.4.2])
#PKG_CHECK_MODULES([apr_util],[apr-util-1 >= 1.3.9]) 

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

dnl DB_TYPE
AC_ARG_WITH(db-type,
        AC_HELP_STRING([--with-db-type=TYPE],
                   [sort of database RT will use (default: Pg) (only Pg currently valid)]),
            DB_TYPE=$withval,
            DB_TYPE=Pg)
if test "$DB_TYPE" != 'Pg' ; then
    AC_MSG_ERROR([Only Pg is a valid db type])
fi
AC_SUBST(DB_TYPE)
DB_UNIXOWNER=postgres
AC_SUBST(DB_UNIXOWNER)

dnl DB_HOST
AC_ARG_WITH(db-host,
        AC_HELP_STRING([--with-db-host=HOSTNAME],
                   [FQDN of database server (default: localhost)]),
            DB_HOST=$withval,
            DB_HOST=localhost)
AC_SUBST(DB_HOST)

dnl DB_PORT
AC_ARG_WITH(db-port,
        AC_HELP_STRING([--with-db-port=PORT],
                   [port on which the database listens on (default: 5432]),
            DB_PORT=$withval,
            DB_PORT=5432)
AC_SUBST(DB_PORT)

AC_ARG_WITH(db-dba,
        AC_HELP_STRING([--with-db-dba=DBA],
                   [name of database administrator (default: postgres)]),
            DB_DBA=$withval,
            DB_DBA="postgres")
AC_SUBST(DB_DBA)

dnl DB_DATABASE
AC_ARG_WITH(db-database,
        AC_HELP_STRING([--with-db-database=DBNAME],
                   [name of the database to use (default: cif_route)]),
            DB_DATABASE=$withval,
            DB_DATABASE=cif)
AC_SUBST(DB_DATABASE)

AC_OUTPUT
