#!/usr/bin/env python
"""
Python bindings for the LLVM Remarks C API.
"""

from __future__ import annotations

from ctypes import (
    CDLL,
    POINTER,
    Structure,
    byref,
    c_char_p,
    c_uint,
    c_uint32,
    c_uint64,
    c_void_p,
    cast,
)
import os
import sys
from enum import IntEnum
from typing import Iterator, Optional, List, Tuple


class RemarkType(IntEnum):
    Unknown = 0
    Passed = 1
    Missed = 2
    Analysis = 3
    AnalysisFPCommute = 4
    AnalysisAliasing = 5
    Failure = 6


class LLVMRemarkOpaqueString(Structure):
    pass

class LLVMRemarkOpaqueDebugLoc(Structure):
    pass

class LLVMRemarkOpaqueArg(Structure):
    pass

class LLVMRemarkOpaqueEntry(Structure):
    pass

class LLVMRemarkOpaqueParser(Structure):
    pass

LLVMRemarkStringRef = POINTER(LLVMRemarkOpaqueString)
LLVMRemarkDebugLocRef = POINTER(LLVMRemarkOpaqueDebugLoc)
LLVMRemarkArgRef = POINTER(LLVMRemarkOpaqueArg)
LLVMRemarkEntryRef = POINTER(LLVMRemarkOpaqueEntry)
LLVMRemarkParserRef = POINTER(LLVMRemarkOpaqueParser)


class RemarksLibrary:
    """Wrapper for the LLVM Remarks C library."""

    _lib = None
    _lib_path = None

    @classmethod
    def get_library(cls):
        if cls._lib is not None:
            return cls._lib

        # Try to find the library
        lib_names = [
            "libRemarks.so",  # Linux
            "libRemarks.dylib",  # macOS
            "Remarks.dll",  # Windows
            "libLLVM.so",  # Linux (if Remarks is part of libLLVM)
            "libLLVM.dylib",  # macOS (if Remarks is part of libLLVM)
        ]

        search_paths = []

        # Add common LLVM library paths
        if "LLVM_LIB_DIR" in os.environ:
            search_paths.append(os.environ["LLVM_LIB_DIR"])

        # Try to find from current script location
        script_dir = os.path.dirname(os.path.abspath(__file__))
        llvm_build_lib = os.path.join(script_dir, "..", "..", "lib")
        if os.path.exists(llvm_build_lib):
            search_paths.append(os.path.abspath(llvm_build_lib))

        # Add system paths
        if sys.platform == "darwin":
            search_paths.extend(
                [
                    "/usr/local/opt/llvm/lib",
                    "/opt/homebrew/opt/llvm/lib",
                ]
            )
        elif sys.platform.startswith("linux"):
            search_paths.extend(
                [
                    "/usr/lib",
                    "/usr/local/lib",
                    "/usr/lib/llvm/lib",
                ]
            )

        lib = None
        for path in search_paths:
            for name in lib_names:
                lib_path = os.path.join(path, name)
                if os.path.exists(lib_path):
                    try:
                        print(f"Trying {lib_path}")
                        lib = CDLL(lib_path)
                        cls._lib_path = lib_path
                        break
                    except OSError as e:
                        print(e)
                        continue
            if lib:
                break

        if lib is None:
            # Try with system loader
            for name in lib_names:
                try:
                    lib = CDLL(name)
                    cls._lib_path = name
                    break
                except OSError:
                    continue

        if lib is None:
            raise RuntimeError(
                "Could not find LLVM Remarks library. "
                "Set LLVM_LIB_DIR environment variable to the directory containing the library."
            )

        cls._lib = lib
        cls._register_functions()
        return lib

    @classmethod
    def _register_functions(cls):
        lib = cls._lib

        # String functions
        lib.LLVMRemarkStringGetData.argtypes = [LLVMRemarkStringRef]
        lib.LLVMRemarkStringGetData.restype = c_char_p

        lib.LLVMRemarkStringGetLen.argtypes = [LLVMRemarkStringRef]
        lib.LLVMRemarkStringGetLen.restype = c_uint32

        # DebugLoc functions
        lib.LLVMRemarkDebugLocGetSourceFilePath.argtypes = [LLVMRemarkDebugLocRef]
        lib.LLVMRemarkDebugLocGetSourceFilePath.restype = LLVMRemarkStringRef

        lib.LLVMRemarkDebugLocGetSourceLine.argtypes = [LLVMRemarkDebugLocRef]
        lib.LLVMRemarkDebugLocGetSourceLine.restype = c_uint32

        lib.LLVMRemarkDebugLocGetSourceColumn.argtypes = [LLVMRemarkDebugLocRef]
        lib.LLVMRemarkDebugLocGetSourceColumn.restype = c_uint32

        # Arg functions
        lib.LLVMRemarkArgGetKey.argtypes = [LLVMRemarkArgRef]
        lib.LLVMRemarkArgGetKey.restype = LLVMRemarkStringRef

        lib.LLVMRemarkArgGetValue.argtypes = [LLVMRemarkArgRef]
        lib.LLVMRemarkArgGetValue.restype = LLVMRemarkStringRef

        lib.LLVMRemarkArgGetDebugLoc.argtypes = [LLVMRemarkArgRef]
        lib.LLVMRemarkArgGetDebugLoc.restype = LLVMRemarkDebugLocRef

        # Entry functions
        lib.LLVMRemarkEntryDispose.argtypes = [LLVMRemarkEntryRef]
        lib.LLVMRemarkEntryDispose.restype = None

        lib.LLVMRemarkEntryGetType.argtypes = [LLVMRemarkEntryRef]
        lib.LLVMRemarkEntryGetType.restype = c_uint

        lib.LLVMRemarkEntryGetPassName.argtypes = [LLVMRemarkEntryRef]
        lib.LLVMRemarkEntryGetPassName.restype = LLVMRemarkStringRef

        lib.LLVMRemarkEntryGetRemarkName.argtypes = [LLVMRemarkEntryRef]
        lib.LLVMRemarkEntryGetRemarkName.restype = LLVMRemarkStringRef

        lib.LLVMRemarkEntryGetFunctionName.argtypes = [LLVMRemarkEntryRef]
        lib.LLVMRemarkEntryGetFunctionName.restype = LLVMRemarkStringRef

        lib.LLVMRemarkEntryGetDebugLoc.argtypes = [LLVMRemarkEntryRef]
        lib.LLVMRemarkEntryGetDebugLoc.restype = LLVMRemarkDebugLocRef

        lib.LLVMRemarkEntryGetHotness.argtypes = [LLVMRemarkEntryRef]
        lib.LLVMRemarkEntryGetHotness.restype = c_uint64

        lib.LLVMRemarkEntryGetNumArgs.argtypes = [LLVMRemarkEntryRef]
        lib.LLVMRemarkEntryGetNumArgs.restype = c_uint32

        lib.LLVMRemarkEntryGetFirstArg.argtypes = [LLVMRemarkEntryRef]
        lib.LLVMRemarkEntryGetFirstArg.restype = LLVMRemarkArgRef

        lib.LLVMRemarkEntryGetNextArg.argtypes = [LLVMRemarkArgRef, LLVMRemarkEntryRef]
        lib.LLVMRemarkEntryGetNextArg.restype = LLVMRemarkArgRef

        # Parser functions
        lib.LLVMRemarkParserCreateYAML.argtypes = [c_void_p, c_uint64]
        lib.LLVMRemarkParserCreateYAML.restype = LLVMRemarkParserRef

        lib.LLVMRemarkParserCreateBitstream.argtypes = [c_void_p, c_uint64]
        lib.LLVMRemarkParserCreateBitstream.restype = LLVMRemarkParserRef

        lib.LLVMRemarkParserCreateAuto.argtypes = [c_void_p, c_uint64]
        lib.LLVMRemarkParserCreateAuto.restype = LLVMRemarkParserRef

        lib.LLVMRemarkParserGetNext.argtypes = [LLVMRemarkParserRef]
        lib.LLVMRemarkParserGetNext.restype = LLVMRemarkEntryRef

        lib.LLVMRemarkParserHasError.argtypes = [LLVMRemarkParserRef]
        lib.LLVMRemarkParserHasError.restype = c_uint

        lib.LLVMRemarkParserGetErrorMessage.argtypes = [LLVMRemarkParserRef]
        lib.LLVMRemarkParserGetErrorMessage.restype = c_char_p

        lib.LLVMRemarkParserDispose.argtypes = [LLVMRemarkParserRef]
        lib.LLVMRemarkParserDispose.restype = None

        lib.LLVMRemarkVersion.argtypes = []
        lib.LLVMRemarkVersion.restype = c_uint32


def _string_ref_to_str(string_ref: LLVMRemarkStringRef) -> str:
    if not string_ref:
        return ""
    lib = RemarksLibrary.get_library()
    data = lib.LLVMRemarkStringGetData(string_ref)
    length = lib.LLVMRemarkStringGetLen(string_ref)
    if data:
        return data[:length].decode("utf-8", errors="replace")
    return ""


class DebugLoc:

    def __init__(self, ref: LLVMRemarkDebugLocRef):
        self._ref = ref
        lib = RemarksLibrary.get_library()

        if ref:
            file_ref = lib.LLVMRemarkDebugLocGetSourceFilePath(ref)
            self.file = _string_ref_to_str(file_ref)
            self.line = lib.LLVMRemarkDebugLocGetSourceLine(ref)
            self.column = lib.LLVMRemarkDebugLocGetSourceColumn(ref)
        else:
            self.file = ""
            self.line = 0
            self.column = 0

    def to_dict(self) -> dict:
        return {"File": self.file, "Line": self.line, "Column": self.column}

    def __repr__(self):
        return f"DebugLoc(file={self.file!r}, line={self.line}, column={self.column})"


class Arg:
    def __init__(self, ref: LLVMRemarkArgRef, entry_ref: LLVMRemarkEntryRef):
        self._ref = ref
        lib = RemarksLibrary.get_library()

        key_ref = lib.LLVMRemarkArgGetKey(ref)
        self.key = _string_ref_to_str(key_ref)

        value_ref = lib.LLVMRemarkArgGetValue(ref)
        self.value = _string_ref_to_str(value_ref)

        debug_loc_ref = lib.LLVMRemarkArgGetDebugLoc(ref)
        self.debug_loc = DebugLoc(debug_loc_ref) if debug_loc_ref else None

    def to_dict(self) -> dict:
        result = {self.key: self.value}
        if self.debug_loc:
            return {self.key: self.value, "DebugLoc": self.debug_loc.to_dict()}
        return result

    def __repr__(self):
        return f"Arg(key={self.key!r}, value={self.value!r})"


class RemarkEntry:

    def __init__(self, ref: LLVMRemarkEntryRef):
        self._ref = ref
        lib = RemarksLibrary.get_library()

        # Get basic properties
        self.remark_type = RemarkType(lib.LLVMRemarkEntryGetType(ref))

        pass_name_ref = lib.LLVMRemarkEntryGetPassName(ref)
        self.pass_name = _string_ref_to_str(pass_name_ref)

        remark_name_ref = lib.LLVMRemarkEntryGetRemarkName(ref)
        self.remark_name = _string_ref_to_str(remark_name_ref)

        function_name_ref = lib.LLVMRemarkEntryGetFunctionName(ref)
        self.function_name = _string_ref_to_str(function_name_ref)

        # Get debug location
        debug_loc_ref = lib.LLVMRemarkEntryGetDebugLoc(ref)
        self.debug_loc = DebugLoc(debug_loc_ref) if debug_loc_ref else None

        # Get hotness
        self.hotness = lib.LLVMRemarkEntryGetHotness(ref)

        # Get arguments
        self.args = []
        arg_ref = lib.LLVMRemarkEntryGetFirstArg(ref)
        while arg_ref:
            self.args.append(Arg(arg_ref, ref))
            arg_ref = lib.LLVMRemarkEntryGetNextArg(arg_ref, ref)

    def to_dict(self) -> dict:
        result = {
            "Pass": self.pass_name,
            "Name": self.remark_name,
            "Function": self.function_name,
        }

        if self.debug_loc:
            result["DebugLoc"] = self.debug_loc.to_dict()

        if self.hotness > 0:
            result["Hotness"] = self.hotness

        if self.args:
            result["Args"] = [arg.to_dict() for arg in self.args]

        return result

    def __del__(self):
        if hasattr(self, "_ref") and self._ref:
            lib = RemarksLibrary.get_library()
            lib.LLVMRemarkEntryDispose(self._ref)
            self._ref = None

    def __repr__(self):
        return (
            f"RemarkEntry(type={self.remark_type.name}, "
            f"pass={self.pass_name!r}, name={self.remark_name!r})"
        )


class RemarkParser:

    def __init__(self, buffer: bytes, format: str = "auto"):
        self._buffer = buffer
        self._format = format
        self._parser = None

        lib = RemarksLibrary.get_library()

        buf_ptr = cast(c_char_p(buffer), c_void_p)
        buf_size = len(buffer)

        if format.lower() == "auto":
            self._parser = lib.LLVMRemarkParserCreateAuto(buf_ptr, buf_size)
        elif format.lower() == "yaml":
            self._parser = lib.LLVMRemarkParserCreateYAML(buf_ptr, buf_size)
        elif format.lower() == "bitstream":
            self._parser = lib.LLVMRemarkParserCreateBitstream(buf_ptr, buf_size)
        else:
            raise ValueError(
                f"Unknown format: {format}. Use 'auto', 'yaml', or 'bitstream'."
            )

        if not self._parser:
            raise RuntimeError("Failed to create remark parser")

    def __iter__(self) -> Iterator[RemarkEntry]:
        lib = RemarksLibrary.get_library()

        while True:
            entry_ref = lib.LLVMRemarkParserGetNext(self._parser)

            if not entry_ref:
                if lib.LLVMRemarkParserHasError(self._parser):
                    error_msg = lib.LLVMRemarkParserGetErrorMessage(self._parser)
                    if error_msg:
                        raise RuntimeError(f"Parser error: {error_msg.decode('utf-8')}")
                    raise RuntimeError("Parser error (no error message)")
                # End of file
                break

            yield RemarkEntry(entry_ref)

    def __del__(self):
        if hasattr(self, "_parser") and self._parser:
            lib = RemarksLibrary.get_library()
            lib.LLVMRemarkParserDispose(self._parser)
            self._parser = None

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.__del__()
        return False


def parse_file(file_path: str) -> Iterator[RemarkEntry]:
    with open(file_path, "rb") as f:
        buffer = f.read()

    with RemarkParser(buffer, "auto") as parser:
        yield from parser
