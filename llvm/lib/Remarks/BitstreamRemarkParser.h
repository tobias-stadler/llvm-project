//===-- BitstreamRemarkParser.h - Parser for Bitstream remarks --*- C++/-*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file provides the impementation of the Bitstream remark parser.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_REMARKS_BITSTREAM_REMARK_PARSER_H
#define LLVM_LIB_REMARKS_BITSTREAM_REMARK_PARSER_H

#include "llvm/ADT/StringRef.h"
#include "llvm/Bitstream/BitstreamReader.h"
#include "llvm/Remarks/BitstreamRemarkContainer.h"
#include "llvm/Remarks/Remark.h"
#include "llvm/Remarks/RemarkFormat.h"
#include "llvm/Remarks/RemarkParser.h"
#include "llvm/Remarks/RemarkStringTable.h"
#include "llvm/Support/Error.h"
#include <cstdint>
#include <memory>
#include <optional>

namespace llvm {
namespace remarks {

struct Remark;

class BitstreamBlockParserHelperBase {
protected:
  BitstreamCursor &Stream;

  unsigned BlockID;
  const char *BlockName;

public:
  BitstreamBlockParserHelperBase(BitstreamCursor &Stream, unsigned BlockID,
                                 const char *BlockName)
      : Stream(Stream), BlockID(BlockID), BlockName(BlockName) {}

public:
  template <typename... Ts> Error error(char const *Fmt, const Ts &...Vals) {
    std::string Buffer;
    raw_string_ostream OS(Buffer);
    OS << "Error while parsing " << BlockName << ": ";
    if constexpr (sizeof...(Vals) == 0) {
      OS << Fmt;
    } else {
      OS << format(Fmt, Vals...);
    }
    return make_error<StringError>(
        Buffer, std::make_error_code(std::errc::illegal_byte_sequence));
  }

  Error unknownRecord(unsigned AbbrevID) {
    return error("Unknown record entry (%lu).", AbbrevID);
  }

  Error unexpectedRecord(StringRef RecordName) {
    return error("Unexpected record entry (%s).", RecordName.data());
  }

  Error malformedRecord(StringRef RecordName) {
    return error("Malformed record entry (%s).", RecordName.data());
  }

  Error unexpectedBlock(unsigned Code) {
    return error("Unexpected block while parsing bitstream.");
  }

public:
  Error enterBlock();
  Error expectBlock();
};

template <typename Derived>
class BitstreamBlockParserHelper : public BitstreamBlockParserHelperBase {
protected:
  using BitstreamBlockParserHelperBase::BitstreamBlockParserHelperBase;
  Derived &derived() { return *static_cast<Derived *>(this); }

  Error parseRecord(unsigned Code) { return unexpectedRecord(Code); }

  Error parseSubBlock(unsigned Code) { return unexpectedBlock(Code); }

public:
  Error parseBlock() {
    if (Error E = enterBlock())
      return E;

    // Stop when there is nothing to read anymore or when we encounter an
    // END_BLOCK.
    while (true) {
      Expected<BitstreamEntry> Next = Stream.advance();
      if (!Next)
        return Next.takeError();
      switch (Next->Kind) {
      case BitstreamEntry::SubBlock:
        if (Error E = derived().parseSubBlock(Next->ID))
          return E;
        continue;
      case BitstreamEntry::EndBlock:
        return Error::success();
      case BitstreamEntry::Record:
        if (Error E = derived().parseRecord(Next->ID))
          return E;
        continue;
      case BitstreamEntry::Error:
        return error("Unexpected end of bitstream.");
      }
    }
  }
};

/// Helper to parse a META_BLOCK for a bitstream remark container.
struct BitstreamMetaParserHelper
    : public BitstreamBlockParserHelper<BitstreamMetaParserHelper> {
  friend class BitstreamBlockParserHelper;

  struct ContainerInfo {
    uint64_t Version;
    uint64_t Type;
  };
  std::optional<ContainerInfo> Container;
  std::optional<uint64_t> RemarkVersion;
  std::optional<StringRef> ExternalFilePath;
  std::optional<StringRef> StrTabBuf;

  /// The parsed content: depending on the container type, some fields might
  /// be empty.

  BitstreamMetaParserHelper(BitstreamCursor &Stream)
      : BitstreamBlockParserHelper(Stream, META_BLOCK_ID, "META_BLOCK") {}

  /// Continue parsing with \p Stream. \p Stream is expected to contain a
  /// ENTER_SUBBLOCK to the META_BLOCK at the current position.
  /// \p Stream is expected to have a BLOCKINFO_BLOCK set.
  /// Parse the META_BLOCK and fill the available entries.
  /// This helper does not check for the validity of the fields.

protected:
  Error parseRecord(unsigned Code);
};

/// Helper to parse a REMARK_BLOCK for a bitstream remark container.
struct BitstreamRemarksParserHelper
    : public BitstreamBlockParserHelper<BitstreamRemarksParserHelper> {
  friend class BitstreamBlockParserHelper;

  enum class ScopeKind {
    None,
    Remark,
    Argument,
  };
  enum class BlockState {
    Init,
    BetweenRemarks,
    InRemark,
    EndOfBlock,
  };
  struct RemarkLoc {
    uint64_t SourceFileNameIdx;
    uint64_t SourceLine;
    uint64_t SourceColumn;
  };
  struct Argument {
    std::optional<uint64_t> KeyIdx;
    std::optional<uint64_t> ValueIdx;
    std::optional<RemarkLoc> DbgLoc;
    bool IsInt = false;
    std::optional<Tag> Tag;
  };

  /// The parsed content: depending on the remark, some fields might be empty.
  std::optional<uint8_t> Type;
  std::optional<uint64_t> RemarkNameIdx;
  std::optional<uint64_t> PassNameIdx;
  std::optional<uint64_t> FunctionNameIdx;
  std::optional<uint64_t> Hotness;
  std::optional<RemarkLoc> DbgLoc;
  std::optional<StringRef> Blob;

  SmallVector<Argument, 8> Args;
  SmallVector<Tag, 8> Tags;

  ScopeKind CurrScope = ScopeKind::None;
  BlockState State = BlockState::Init;

  unsigned RecordID;
  SmallVector<uint64_t, 5> Record;
  StringRef RecordBlob;

  BitstreamRemarksParserHelper(BitstreamCursor &Stream)
      : BitstreamBlockParserHelper(Stream, REMARKS_BLOCK_ID, "REMARKS_BLOCK") {}

  /// Continue parsing with \p Stream. \p Stream is expected to contain a
  /// ENTER_SUBBLOCK to the REMARK_BLOCK at the current position.
  /// \p Stream is expected to have a BLOCKINFO_BLOCK set and to have already
  /// parsed the META_BLOCK.
  /// Parse the REMARK_BLOCK and fill the available entries.
  /// This helper does not check for the validity of the fields.
  Error parseNext();
  Error advance();

  bool isRemarkBoundary(unsigned RecordID) {
    switch (RecordID) {
      case RECORD_REMARK:
      case RECORD_REMARK_HEADER:
        return true;
      default:
        return false;
    }
  }

protected:
  Error handleRecord();
};

/// Helper to parse any bitstream remark container.
struct BitstreamParserHelper {
  /// The Bitstream reader.
  BitstreamCursor Stream;
  /// The block info block.
  BitstreamBlockInfo BlockInfo;

  BitstreamMetaParserHelper MetaHelper;
  std::optional<BitstreamRemarksParserHelper> RemarksHelper;
  std::optional<uint64_t> RemarkStartBitPos;
  bool MetaRdy = false;

  /// Start parsing at \p Buffer.
  BitstreamParserHelper(StringRef Buffer)
      : Stream(Buffer), MetaHelper(Stream), RemarksHelper(Stream) {}

  /// Parse the magic number.
  Error expectMagic();
  /// Parse the block info block containing all the abbrevs.
  /// This needs to be called before calling any other parsing function.
  Error parseBlockInfoBlock();

  Error parseMeta();
  Error parseRemark();
};

/// Parses and holds the state of the latest parsed remark.
struct BitstreamRemarkParser : public RemarkParser {
  /// The buffer to parse.
  std::optional<BitstreamParserHelper> ParserHelper;
  /// The string table used for parsing strings.
  std::optional<ParsedStringTable> StrTab;
  /// Temporary remark buffer used when the remarks are stored separately.
  std::unique_ptr<MemoryBuffer> TmpRemarkBuffer;
  StringTable TmpStrTab;
  /// The common metadata used to decide how to parse the buffer.
  /// This is filled when parsing the metadata block.
  uint64_t ContainerVersion = 0;
  uint64_t RemarkVersion = 0;
  BitstreamRemarkContainerType ContainerType =
      BitstreamRemarkContainerType::RemarksFile;

  /// Create a parser that expects to find a string table embedded in the
  /// stream.
  explicit BitstreamRemarkParser(StringRef Buf)
      : RemarkParser(Format::Bitstream), ParserHelper(Buf) {}

  /// Create a parser that uses a pre-parsed string table.
  BitstreamRemarkParser(StringRef Buf, ParsedStringTable StrTab)
      : RemarkParser(Format::Bitstream), ParserHelper(Buf),
        StrTab(std::move(StrTab)) {}

  Expected<std::unique_ptr<Remark>> next() override;

  static bool classof(const RemarkParser *P) {
    return P->ParserFormat == Format::Bitstream;
  }

  /// Parse and process the metadata of the buffer.
  Error parseMeta();

private:
  Error processCommonMeta();
  Error processFileContainerMeta();
  Error processExternalFilePath();

  Expected<std::unique_ptr<Remark>> processRemark();

  Error processStrTab();
  Error processRemarkVersion();
};

Expected<std::unique_ptr<BitstreamRemarkParser>> createBitstreamParserFromMeta(
    StringRef Buf,
    std::optional<StringRef> ExternalFilePrependPath = std::nullopt);

} // end namespace remarks
} // end namespace llvm

#endif /* LLVM_LIB_REMARKS_BITSTREAM_REMARK_PARSER_H */
