#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.64])
AC_INIT(cif-protocol, m4_esyscmd_s([git describe --tags]), [ci-framework@googlegroups.com])
AM_INIT_AUTOMAKE

# Checks for programs.
AC_ARG_WITH([perl], [AS_HELP_STRING([--with-perl],
    [build perl bindings [default=no]])],
    [with_perl=$withval],[with_perl=yes])

if test "x$with_perl" != "xno"; then
    AC_ARG_VAR([PERL],[Perl interpreter command])
    AC_PATH_PROG([PERL], [perl], [not found])
    if test "$PERL" = 'not found'; then
        AC_MSG_ERROR([cannot use $PACKAGE_NAME without perl])
    fi
fi

AC_ARG_WITH([python], [AS_HELP_STRING([--with-python],
    [build python bindings [default=no]])],
    [with_python=$withval],[with_python=yes])

if test "x$with_python" != "xno"; then
    AC_ARG_VAR([PYTHON],[Python interpreter command])
    AC_PATH_PROG([PYTHON], [python], [not found])
    if test "$PYTHON" = 'not found'; then
        AC_MSG_ERROR([cannot use $PACKAGE_NAME without python])
    fi
fi

#AC_PATH_PROG([PROTOC], [protoc], [not found])
#    if test "$PROTOC" = 'not found'; then
#        AC_MSG_ERROR([cannot use $PACKAGE_NAME without protoc])
#    fi

AC_CONFIG_FILES([
                 Makefile
])


# Checks for libraries.

#PKG_CHECK_MODULES([protobuf],[protobuf >= 2.4.1])

# Checks for header files.

# Checks for typedefs, structures, and compiler characteristics.

# Checks for library functions.

AC_OUTPUT
