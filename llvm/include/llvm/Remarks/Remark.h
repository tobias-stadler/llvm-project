//===-- llvm/Remarks/Remark.h - The remark type -----------------*- C++/-*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines an abstraction for handling remarks.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_REMARKS_REMARK_H
#define LLVM_REMARKS_REMARK_H

#include "llvm-c/Remarks.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallSet.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/CBindingWrapping.h"
#include "llvm/Support/Compiler.h"
#include "llvm/Support/raw_ostream.h"
#include <cassert>
#include <cstdint>
#include <optional>
#include <string>

namespace llvm {
namespace remarks {

/// The current version of the remark entry.
constexpr uint64_t CurrentRemarkVersion = 1;

/// The debug location used to track a remark back to the source file.
struct RemarkLocation {
  /// Absolute path of the source file corresponding to this remark.
  StringRef SourceFilePath;
  unsigned SourceLine = 0;
  unsigned SourceColumn = 0;

  /// Implement operator<< on RemarkLocation.
  LLVM_ABI void print(raw_ostream &OS) const;
};

// Create wrappers for C Binding types (see CBindingWrapping.h).
DEFINE_SIMPLE_CONVERSION_FUNCTIONS(RemarkLocation, LLVMRemarkDebugLocRef)

class Tag {
  uint64_t Val;

  constexpr explicit Tag(uint64_t Val) : Val(Val) {}

public:
  enum Kind {
    Passed,
    Missed,
    Failure,
    Statistics,
    GenericBinaryBlob,
    BitCodeBlob,
    IRBlob,
    FPCommute,
    Aliasing,
    Custom,
    FirstBuiltin = Passed,
    LastBuiltin = Custom - 1,
  };

  static constexpr bool isValidBuiltin(uint64_t Val) {
    return Val >= FirstBuiltin && Val <= LastBuiltin;
  }

  constexpr Tag(Kind Val) : Val(Val) {}

  static constexpr Tag fromStrTab(uint64_t Val) { return Tag(Custom + Val); }

  static constexpr Tag fromRaw(uint64_t Val) { return Tag(Val); }

  static constexpr Tag fromBuiltin(uint64_t Val) {
    assert(isValidBuiltin(Val));
    return Tag(Val);
  }

  Kind getKind() const {
    return static_cast<Kind>(Val <= LastBuiltin ? Val : Custom);
  }

  uint64_t getRaw() const { return Val; }

  bool isBinaryBlob() const {
    switch (Val) {
    case GenericBinaryBlob:
    case BitCodeBlob:
      return true;
    default:
      return false;
    }
  }

  bool isBuiltin() { return Val < Custom; }

  StringRef getName() {
    switch (Val) {
    case Passed:
      return "Passed";
    case Missed:
      return "Missed";
    case Failure:
      return "Failure";
    case FPCommute:
      return "FPCommute";
    case Aliasing:
      return "Aliasing";
    case Statistics:
      return "Stats";
    case GenericBinaryBlob:
      return "GenericBinaryBlob";
    case BitCodeBlob:
      return "BitCodeBlob";
    case IRBlob:
      return "IRBlob";
    default:
      return {};
    }
  }

  friend bool operator==(const Tag &LHS, const Tag &RHS) {
    return LHS.Val == RHS.Val;
  }

  friend bool operator!=(const Tag &LHS, const Tag &RHS) {
    return !(LHS == RHS);
  }
  friend bool operator<(const Tag &LHS, const Tag &RHS) {
    return LHS.Val < RHS.Val;
  }
};

class TagSet {
  uint64_t BuiltinTags = 0;
  static_assert(Tag::LastBuiltin < sizeof(BuiltinTags) * CHAR_BIT);

  SmallSet<Tag, 2> ExtraTags;

public:
  void insert(Tag TheTag) {
    if (TheTag.isBuiltin()) {
      BuiltinTags |= (1U << TheTag.getRaw());
      return;
    }
    ExtraTags.insert(TheTag);
  }

  template <typename IterT> void insert(IterT I, IterT E) {
    for (; I != E; ++I)
      insert(*I);
  }

  template <typename Range> void insert_range(Range &&R) {
    insert(adl_begin(R), adl_end(R));
  }

  void erase(Tag TheTag) {
    if (TheTag.isBuiltin()) {
      BuiltinTags &= ~(1U << TheTag.getRaw());
      return;
    }
    ExtraTags.insert(TheTag);
  }

  bool contains(Tag TheTag) const {
    if (TheTag.isBuiltin())
      return BuiltinTags & (1U << TheTag.getRaw());
    return ExtraTags.contains(TheTag);
  }

  class iterator {
  private:
    using It = typename SmallSet<Tag, 2>::const_iterator;

    const TagSet *Parent;
    uint32_t BitIndex;
    It ExtraIt;

    bool isBuiltin() const { return BitIndex <= Tag::LastBuiltin; }

    void advance() {
      if (isBuiltin()) {
        do
          ++BitIndex;
        while (isBuiltin() && !(Parent->BuiltinTags & (1U << BitIndex)));
        return;
      }
      ++ExtraIt;
    }

  public:
    iterator(const TagSet *P, bool End = false)
        : Parent(P), BitIndex(End ? Tag::LastBuiltin + 1 : 0),
          ExtraIt(End ? Parent->ExtraTags.begin() : Parent->ExtraTags.end()) {
      if (End)
        return;
      assert(BitIndex == 0);
      if (!(Parent->BuiltinTags & 1))
        advance();
    }

    Tag operator*() const {
      if (isBuiltin())
        return Tag::fromBuiltin(BitIndex);
      return *ExtraIt;
    }

    iterator &operator++() {
      advance();
      return *this;
    }

    bool operator!=(const iterator &Other) const {
      return BitIndex != Other.BitIndex || ExtraIt != Other.ExtraIt;
    }
  };

  iterator begin() const { return iterator(this); }
  iterator end() const { return iterator(this, true); }

  bool operator==(const TagSet &Other) const {
    return BuiltinTags == Other.BuiltinTags && ExtraTags == Other.ExtraTags;
  }

  bool operator!=(const TagSet &Other) const { return !(*this == Other); }

  std::optional<Tag> containsAnyOf(std::initializer_list<Tag> TheTags) const {
    for (auto TheTag : TheTags)
      if (contains(TheTag))
        return TheTag;
    return std::nullopt;
  }

  bool containsAllOf(std::initializer_list<Tag> TheTags) const {
    for (auto TheTag : TheTags)
      if (!contains(TheTag))
        return false;
    return true;
  }
};

/// A key-value pair with a debug location that is used to display the remarks
/// at the right place in the source.
struct Argument {
  StringRef Key;
  // FIXME: We might want to be able to store other types than strings here.
  StringRef Val;
  // If set, the debug location corresponding to the value.
  std::optional<RemarkLocation> Loc;
  std::optional<Tag> Tag;

  Argument() = default;

  Argument(StringRef Key, StringRef Val,
           std::optional<RemarkLocation> Loc = std::nullopt)
      : Key(Key), Val(Val), Loc(Loc) {}

  /// Implement operator<< on Argument.
  LLVM_ABI void print(raw_ostream &OS) const;
  /// Return the value of argument as int.
  LLVM_ABI std::optional<int> getValAsInt() const;
  /// Check if the argument value can be parsed as int.
  LLVM_ABI bool isValInt() const;
};

// Create wrappers for C Binding types (see CBindingWrapping.h).
DEFINE_SIMPLE_CONVERSION_FUNCTIONS(Argument, LLVMRemarkArgRef)

/// The type of the remark.
enum class Type {
  Unknown,
  Passed,
  Missed,
  Analysis,
  AnalysisFPCommute,
  AnalysisAliasing,
  Failure,
  First = Unknown,
  Last = Failure
};

inline StringRef typeToStr(Type Ty) {
  switch (Ty) {
  case Type::Unknown:
    return "Unknown";
  case Type::Missed:
    return "Missed";
  case Type::Passed:
    return "Passed";
  case Type::Analysis:
    return "Analysis";
  case Type::AnalysisFPCommute:
    return "AnalysisFPCommute";
  case Type::AnalysisAliasing:
    return "AnalysisAliasing";
  default:
    return "Failure";
  }
}

/// A remark type used for both emission and parsing.
struct Remark {
  /// The type of the remark.
  Type RemarkType = Type::Unknown;

  TagSet Tags;

  /// Name of the pass that triggers the emission of this remark.
  StringRef PassName;

  /// Textual identifier for the remark (single-word, camel-case). Can be used
  /// by external tools reading the output file for remarks to identify the
  /// remark.
  StringRef RemarkName;

  /// Mangled name of the function that triggers the emssion of this remark.
  StringRef FunctionName;

  /// The location in the source file of the remark.
  std::optional<RemarkLocation> Loc;

  /// If profile information is available, this is the number of times the
  /// corresponding code was executed in a profile instrumentation run.
  std::optional<uint64_t> Hotness;

  /// Arguments collected via the streaming interface.
  SmallVector<Argument, 5> Args;

  std::optional<StringRef> Blob;

  Remark() = default;
  Remark(Remark &&) = default;
  Remark &operator=(Remark &&) = default;

  /// Return a message composed from the arguments as a string.
  LLVM_ABI std::string getArgsAsMsg() const;

  /// Clone this remark to explicitly ask for a copy.
  Remark clone() const { return *this; }

  /// Implement operator<< on Remark.
  LLVM_ABI void print(raw_ostream &OS) const;

  Argument *getArgByKey(StringRef Key) {
    for (auto &Arg : Args) {
      if (Arg.Key == Key)
        return &Arg;
    }
    return nullptr;
  }

private:
  /// In order to avoid unwanted copies, "delete" the copy constructor.
  /// If a copy is needed, it should be done through `Remark::clone()`.
  Remark(const Remark &) = default;
  Remark& operator=(const Remark &) = default;
};

// Create wrappers for C Binding types (see CBindingWrapping.h).
DEFINE_SIMPLE_CONVERSION_FUNCTIONS(Remark, LLVMRemarkEntryRef)

/// Comparison operators for Remark objects and dependent objects.

template <typename T>
bool operator<(const std::optional<T> &LHS, const std::optional<T> &RHS) {
  // Sorting based on optionals should result in all `None` entries to appear
  // before the valid entries. For example, remarks with no debug location will
  // appear first.
  if (!LHS && !RHS)
    return false;
  if (!LHS && RHS)
    return true;
  if (LHS && !RHS)
    return false;
  return *LHS < *RHS;
}

inline bool operator==(const RemarkLocation &LHS, const RemarkLocation &RHS) {
  return LHS.SourceFilePath == RHS.SourceFilePath &&
         LHS.SourceLine == RHS.SourceLine &&
         LHS.SourceColumn == RHS.SourceColumn;
}

inline bool operator!=(const RemarkLocation &LHS, const RemarkLocation &RHS) {
  return !(LHS == RHS);
}

inline bool operator<(const RemarkLocation &LHS, const RemarkLocation &RHS) {
  return std::make_tuple(LHS.SourceFilePath, LHS.SourceLine, LHS.SourceColumn) <
         std::make_tuple(RHS.SourceFilePath, RHS.SourceLine, RHS.SourceColumn);
}

inline bool operator==(const Argument &LHS, const Argument &RHS) {
  return LHS.Key == RHS.Key && LHS.Val == RHS.Val && LHS.Tag == RHS.Tag && LHS.Loc == RHS.Loc;
}

inline bool operator!=(const Argument &LHS, const Argument &RHS) {
  return !(LHS == RHS);
}

inline bool operator<(const Argument &LHS, const Argument &RHS) {
  return std::make_tuple(LHS.Key, LHS.Val, LHS.Tag, LHS.Loc) <
         std::make_tuple(RHS.Key, RHS.Val, RHS.Tag, RHS.Loc);
}

inline bool operator==(const Remark &LHS, const Remark &RHS) {
  return LHS.RemarkType == RHS.RemarkType && LHS.PassName == RHS.PassName &&
         LHS.RemarkName == RHS.RemarkName &&
         LHS.FunctionName == RHS.FunctionName && LHS.Loc == RHS.Loc &&
         LHS.Hotness == RHS.Hotness && LHS.Args == RHS.Args;
}

inline bool operator!=(const Remark &LHS, const Remark &RHS) {
  return !(LHS == RHS);
}

inline bool operator<(const Remark &LHS, const Remark &RHS) {
  return std::make_tuple(LHS.RemarkType, LHS.PassName, LHS.RemarkName,
                         LHS.FunctionName, LHS.Loc, LHS.Hotness, LHS.Args) <
         std::make_tuple(RHS.RemarkType, RHS.PassName, RHS.RemarkName,
                         RHS.FunctionName, RHS.Loc, RHS.Hotness, RHS.Args);
}

inline raw_ostream &operator<<(raw_ostream &OS, const RemarkLocation &RLoc) {
  RLoc.print(OS);
  return OS;
}

inline raw_ostream &operator<<(raw_ostream &OS, const Argument &Arg) {
  Arg.print(OS);
  return OS;
}

inline raw_ostream &operator<<(raw_ostream &OS, const Remark &Remark) {
  Remark.print(OS);
  return OS;
}

} // end namespace remarks
} // end namespace llvm

#endif /* LLVM_REMARKS_REMARK_H */
