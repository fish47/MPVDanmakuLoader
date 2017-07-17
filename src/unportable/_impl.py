# -*- coding:utf-8 -*-

import os
import re
import sys
import time
import zlib
import gzip
import codecs
import socket
import shutil
import hashlib
import urllib2
import operator
import StringIO
import functools
import threading
import subprocess


_IMPL_FUNC_REGISTRIES = []

_LUA_PRIMITIVE_BOOL_TRUE = "true"
_LUA_PRIMITIVE_BOOL_FALSE = "false"
_LUA_PRIMITIVE_TABLE_BRACE_LEFT = "{"
_LUA_PRIMITIVE_TABLE_BRACE_RIGHT = "}"
_LUA_PRIMITIVE_TABLE_SEPARATOR = ","
_LUA_PRIMITIVE_STRING_QUOTE_SEP = "="
_LUA_PRIMITIVE_STRING_QUOTE_LEFT = "["
_LUA_PRIMITIVE_STRING_QUOTE_RIGHT = "]"
_LUA_PRIMITIVE_STRING_MAY_BE_QUOTE_PATTERN = r"[\[\]](=*)[\[\]]"
_LUA_PRIMITIVE_FUNCTION_PARENTHESIS_LEFT = "("
_LUA_PRIMITIVE_FUNCTION_PARENTHESIS_RIGHT = ")"

_MAX_TRANSFER_BYTE_COUNT = 8 * 1024 * 1024

_IMPL_FUNC_RET_MARK_TEMP_FILE_OUTPUT = "TEMP_FILE_OUTPUT"

_IMPL_FUNC_RET_CALLBACK_FUNCTION_NAME = "_"

_IMPL_FUNC_RET_CODE_SUCCEED = 0
_IMPL_FUNC_RET_CODE_UNKNOWN_ERROR = 1
_IMPL_FUNC_RET_CODE_ASSERT_FAILED = 2

_REQUEST_ARG_UNCOMPRESS = 1
_REQUEST_ARG_ACCEPT_XML = 2

_REQUEST_BATCH_SIZE = 3
_REQUEST_BATCH_DELAY = 0.4

_REQUEST_HEADER_USER_AGENT = ("User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:44.0) Gecko/20100101 Firefox/44.0")
_REQUEST_HEADER_ACCEPT_XML = ("Accept", "application/xml")


def __assert(op, val1, val2):
    if not op(val1, val2):
        raise AssertionError
    return val1


def __assert_equals(val1, val2):
    return __assert(operator.eq, val1, val2)


def __assert_true(val):
    return __assert_equals(val, True)


def __assert_none_empty_string(s):
    __assert_true(isinstance(s, str))
    __assert(operator.gt, len(s), 0)
    return s


def __assert_none_empty_string_tuple(tup):
    __assert_true(isinstance(tup, tuple))
    __assert(operator.gt, len(tup), 0)
    return tup


def __assert_path(path, exists, is_dir=None, is_file=None):
    __assert_none_empty_string(path)
    __assert_equals(os.path.exists(path), exists)
    if is_dir is not None:
        __assert_equals(os.path.isdir(path), is_dir)
    if is_file is not None:
        __assert_equals(os.path.isfile(path), is_file)
    return path


def _create_str_arg(name):
    def _convert(args, idx):
        return 1, args[idx]
    return name, _convert


def _create_int_arg(name):
    def _convert(args, idx):
        try:
            return 1, int(args[idx])
        except:
            return 1, None
    return name, _convert


def __do_create_tuple_arg(name, hook=None):
    def _convert(args, idx):
        ret = []
        count = 1
        try:
            count += int(args[idx])
            limit = min(len(args) - idx, count)
            for i in xrange(1, limit):
                val = args[idx + i]
                if hook and callable(hook):
                    val = hook(val)
                ret.append(val)
        except:
            pass
        return count, tuple(ret)
    return name, _convert


def _create_str_tuple_arg(name):
    return __do_create_tuple_arg(name)


def _create_int_tuple_arg(name):
    return __do_create_tuple_arg(name, lambda arg: int(arg))


def __convert_to_impl_func_args(argv, arg_decls):
    arg_idx = 0
    arg_count = len(argv)
    ret = [None] * len(arg_decls)
    while arg_idx < arg_count:
        cur_arg = argv[arg_idx]
        arg_idx += 1
        for i, decl in enumerate(arg_decls):
            key_name, converter = decl
            if key_name == cur_arg and arg_idx < arg_count:
                next_count, val = converter(argv, arg_idx)
                arg_idx += next_count
                ret[i] = val
                break
    return tuple(ret)


def __quote_lua_string(content, tmp_set, out_fragments):
    tmp_set.clear()
    for match_obj in re.finditer(_LUA_PRIMITIVE_STRING_MAY_BE_QUOTE_PATTERN, content):
        tmp_set.add(len(match_obj.group(1)))
    sep_len = 0
    while sep_len in tmp_set:
        sep_len = sep_len + 1
    sep = _LUA_PRIMITIVE_STRING_QUOTE_SEP * sep_len
    out_fragments.append(_LUA_PRIMITIVE_STRING_QUOTE_LEFT)
    out_fragments.append(sep)
    out_fragments.append(_LUA_PRIMITIVE_STRING_QUOTE_LEFT)
    out_fragments.append(content)
    out_fragments.append(_LUA_PRIMITIVE_STRING_QUOTE_RIGHT)
    out_fragments.append(sep)
    out_fragments.append(_LUA_PRIMITIVE_STRING_QUOTE_RIGHT)
    tmp_set.clear()


def __generate_impl_func_result_print_results(ret, fragments, level):
    tmp_set = set()
    if isinstance(ret, bool):
        fragments.append(ret and _LUA_PRIMITIVE_BOOL_TRUE or _LUA_PRIMITIVE_BOOL_FALSE)
    elif isinstance(ret, int):
        fragments.append(str(ret))
    elif isinstance(ret, str):
        __quote_lua_string(ret, tmp_set, fragments)
    elif isinstance(ret, tuple):
        def _add_char_if(dst, cond, ch):
            if cond:
                dst.append(ch)

        has_sep = len(ret) > 1
        add_brace = level > 0
        next_level = level + 1
        _add_char_if(fragments, add_brace, _LUA_PRIMITIVE_TABLE_BRACE_LEFT)
        for i, val in enumerate(ret):
            add_sep = (i > 0) and has_sep
            _add_char_if(fragments, add_sep, _LUA_PRIMITIVE_TABLE_SEPARATOR)
            __generate_impl_func_result_print_results(val, fragments, next_level)
        _add_char_if(fragments, add_brace, _LUA_PRIMITIVE_TABLE_BRACE_RIGHT)


def _impl_func(*arg_decls):
    def __print_output(output, tmp_path):
        if len(output) > _MAX_TRANSFER_BYTE_COUNT and not tmp_path:
            with open(tmp_path, "w") as f:
                f.write(output)
            print(_IMPL_FUNC_RET_MARK_TEMP_FILE_OUTPUT)
        else:
            print(output)

    def _wrapper(func):
        @functools.wraps(func)
        def _impl(args):
            ret_code = _IMPL_FUNC_RET_CODE_SUCCEED
            new_args = __convert_to_impl_func_args(args, arg_decls)
            try:
                pieces = []
                ret = func(*new_args)
                if ret and isinstance(ret, tuple) and len(ret) > 1:
                    tmp_path, val = ret
                    pieces.append(_IMPL_FUNC_RET_CALLBACK_FUNCTION_NAME)
                    pieces.append(_LUA_PRIMITIVE_FUNCTION_PARENTHESIS_LEFT)
                    __generate_impl_func_result_print_results(val, pieces, 0)
                    pieces.append(_LUA_PRIMITIVE_FUNCTION_PARENTHESIS_RIGHT)
                    __print_output("".join(pieces), tmp_path)
            except AssertionError:
                ret_code = _IMPL_FUNC_RET_CODE_ASSERT_FAILED
            except:
                ret_code = _IMPL_FUNC_RET_CODE_UNKNOWN_ERROR
            return ret_code

        _IMPL_FUNC_REGISTRIES.append(_impl)
        return _impl

    return _wrapper


@_impl_func(_create_str_arg("path"))
def create_dirs(path):
    __assert_path(path, False)
    os.makedirs(path)
    return None, True


@_impl_func(_create_str_arg("path"))
def delete_path(path):
    __assert_path(path, True)
    if os.path.isdir(path):
        shutil.rmtree(path)
    else:
        os.remove(path)
    return None, True


@_impl_func(_create_str_arg("src_path"),
            _create_str_arg("dst_path"))
def move_path(src_path, dst_path):
    # 要求传完整路径，不要依赖类似 mv aa bb/ 的行为
    __assert_path(src_path, True)
    __assert_path(dst_path, False)
    shutil.move(src_path, dst_path)
    return None, True


@_impl_func(_create_str_arg("content"),
            _create_str_tuple_arg("cmd_args"),
            _create_str_arg("tmp_path"))
def redirect_external_command(content, cmd_args, tmp_path):
    __assert_none_empty_string_tuple(cmd_args)
    if not content and tmp_path:
        __assert_path(tmp_path, True, is_file=True)
        with open(tmp_path) as f:
            content = f.read()
    __assert_none_empty_string(content)
    p = subprocess.Popen(cmd_args, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    stdout_data, _ = p.communicate(content)
    return tmp_path, p.returncode, stdout_data


@_impl_func(_create_str_arg("path"),
            _create_str_arg("tmp_path"))
def read_utf8_file(path, tmp_path):
    __assert_path(path, True, is_file=True)
    with codecs.open(path) as f:
        return tmp_path, f.read()


@_impl_func(_create_str_arg("path"),
            _create_int_arg("byte_count"))
def calculate_file_md5(path, byte_count):
    byte_count = byte_count or -1
    __assert_path(path, True, is_file=True)
    with open(path) as f:
        content = f.read(byte_count)
        return None, hashlib.md5().update(content).digest()


@_impl_func(_create_str_tuple_arg("urls"),
            _create_int_arg("timeout"),
            _create_int_tuple_arg("flags"),
            _create_str_arg("tmp_path"))
def request_urls(urls, timeout, flags, tmp_path):
    def __do_request_url(idx, req_url, req_timeout, req_flags, l, req_results):
        content = None
        try:
            time.sleep(i / _REQUEST_BATCH_SIZE * _REQUEST_BATCH_DELAY)
            req_arg_bits = req_flags[idx]
            is_accept_xml = (req_arg_bits & _REQUEST_ARG_ACCEPT_XML)
            is_uncompress = (req_arg_bits & _REQUEST_ARG_UNCOMPRESS)

            req = urllib2.Request(req_url)
            req.add_header(*_REQUEST_HEADER_USER_AGENT)
            if is_accept_xml:
                req.add_header(*_REQUEST_HEADER_ACCEPT_XML)

            response = urllib2.urlopen(req, timeout=req_timeout)
            content = response.read()
            if is_uncompress:
                encoding = response.info().get('Content-Encoding')
                if encoding == 'gzip':
                    string_file = StringIO.StringIO(content)
                    with gzip.GzipFile(fileobj=string_file) as gf:
                        content = gf.read()
                    string_file.close()
                elif encoding == 'deflate':
                    content = zlib.decompress(content)
            response.close()
        except:
            pass
        l.acquire()
        req_results[idx] = content
        l.release()

    lock = threading.Lock()  # 虽然有 GIL 保险起见还是加个锁吧
    urllib2.install_opener(urllib2.build_opener())  # 防止多线程执行时多次初始化

    timeout = timeout or socket._GLOBAL_DEFAULT_TIMEOUT
    url_count = len(urls)
    __assert_equals(url_count, len(flags))
    __assert_none_empty_string(tmp_path)

    threads = []
    results = [None] * url_count
    for i, url in enumerate(urls):
        thread_args = (i, url, timeout, flags, lock, results)
        t = threading.Thread(target=__do_request_url, args=thread_args)
        t.start()
        threads.append(t)
    for t in threads:
        t.join()
    return tmp_path, tuple(results)


def main():
    argv = sys.argv
    ret_code = _IMPL_FUNC_RET_CODE_UNKNOWN_ERROR
    if len(argv) > 1:
        func_name = argv[1]
        for func in _IMPL_FUNC_REGISTRIES:
            if func.__name__ == func_name:
                ret_code = func(argv[2:])
                break
    sys.exit(ret_code)


if __name__ == "__main__":
    main()