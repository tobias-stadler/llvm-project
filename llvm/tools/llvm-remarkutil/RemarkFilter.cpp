//===- RemarkFilter.cpp ---------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Generic tool to filter remarks
//
//===----------------------------------------------------------------------===//

#include "RemarkUtilHelpers.h"
#include "RemarkUtilRegistry.h"

#include "llvm/Support/Debug.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/Regex.h"

using namespace llvm;
using namespace remarks;
using namespace llvm::remarkutil;

namespace filter {

static cl::SubCommand Filter("filter", "Filter remarks.");

static cl::opt<std::string>
    FunctionOpt("func", cl::sub(Filter), cl::ValueOptional,
                cl::desc("Optional function name to filter collection by"));

static cl::opt<std::string>
    FunctionOptRE("rfunc", cl::sub(Filter), cl::ValueOptional,
                  cl::desc("Optional function name to filter collection by "
                           "(accepts regular expressions)"));
static cl::opt<std::string>
    RemarkNameOpt("remark",
                  cl::desc("Optional remark name to filter collection by."),
                  cl::ValueOptional, cl::sub(Filter));
static cl::opt<std::string>
    RemarkNameOptRE("rremark",
                    cl::desc("Optional remark name to filter collection by "
                             "(accepts regular expressions)."),
                    cl::ValueOptional, cl::sub(Filter));
static cl::opt<std::string>
    PassNameOpt("pass", cl::ValueOptional,
                cl::desc("Optional remark pass name to filter collection by."),
                cl::sub(Filter));
static cl::opt<std::string>
    PassNameOptRE("rpass", cl::ValueOptional,
                  cl::desc("Optional remark pass name to filter collection "
                           "by (accepts regular expressions)."),
                  cl::sub(Filter));
static cl::opt<Type> RemarkTypeOpt(
    "type", cl::desc("Optional remark type to filter collection by."),
    cl::values(clEnumValN(Type::Unknown, "unknown", "UNKOWN"),
               clEnumValN(Type::Passed, "passed", "PASSED"),
               clEnumValN(Type::Missed, "missed", "MISSED"),
               clEnumValN(Type::Analysis, "analysis", "ANALYSIS"),
               clEnumValN(Type::AnalysisFPCommute, "analysis-fp-commute",
                          "ANALYSIS_FP_COMMUTE"),
               clEnumValN(Type::AnalysisAliasing, "analysis-aliasing",
                          "ANALYSIS_ALIASING"),
               clEnumValN(Type::Failure, "failure", "FAILURE")), cl::sub(Filter));

INPUT_FORMAT_COMMAND_LINE_OPTIONS(Filter)
OUTPUT_FORMAT_COMMAND_LINE_OPTIONS(Filter)
INPUT_OUTPUT_COMMAND_LINE_OPTIONS(Filter)

static Error tryFilter() {
  auto MaybeOF = getOutputFileForRemarks(OutputFileName, Format::YAML);
  if (!MaybeOF)
    return MaybeOF.takeError();
  auto FuncFilter = FilterMatcher::createExactOrRE(FunctionOpt, FunctionOptRE);
  auto PassFilter = FilterMatcher::createExactOrRE(PassNameOpt, PassNameOptRE);
  auto RemarkFilter =
      FilterMatcher::createExactOrRE(RemarkNameOpt, RemarkNameOptRE);
  if (!FuncFilter)
    return FuncFilter.takeError();
  if (!PassFilter)
    return PassFilter.takeError();
  if (!RemarkFilter)
    return RemarkFilter.takeError();

  std::optional<Type> TypeFilter;
  if(RemarkTypeOpt.getNumOccurrences())
    TypeFilter = RemarkTypeOpt.getValue();

  auto OF = std::move(*MaybeOF);
  auto MaybeBuf = getInputMemoryBuffer(InputFileName);
  if (!MaybeBuf)
    return MaybeBuf.takeError();
  auto MaybeParser = createRemarkParser(InputFormat, (*MaybeBuf)->getBuffer());
  if (!MaybeParser)
    return MaybeParser.takeError();

  Format OutFormat = (*MaybeParser)->ParserFormat;
  if (OutputFileName == "-")
    OutFormat = Format::YAML;
  if (OutputFormat.getNumOccurrences())
    OutFormat = OutputFormat.getValue();

  StringTable StrTab;
  std::vector<std::unique_ptr<Remark>> Remarks;

  auto &Parser = **MaybeParser;
  auto MaybeRemark = Parser.next();
  for (; MaybeRemark; MaybeRemark = Parser.next()) {
    Remark &Remark = **MaybeRemark;
    if (*FuncFilter && !(*FuncFilter)->match(Remark.FunctionName))
      continue;
    if (*PassFilter && !(*PassFilter)->match(Remark.PassName))
      continue;
    if (*RemarkFilter && !(*RemarkFilter)->match(Remark.RemarkName))
      continue;
    if (TypeFilter && *TypeFilter != Remark.RemarkType)
      continue;
    StrTab.internalize(Remark);
    Remarks.push_back(std::move(*MaybeRemark));
  }

  auto MaybeSerializer =
      createRemarkSerializer(OutFormat, SerializerMode::Standalone, OF->os(), std::move(StrTab));
  if (!MaybeSerializer)
    return MaybeSerializer.takeError();
  auto &Serializer = **MaybeSerializer;
  for (auto &R : Remarks) {
    Serializer.emit(*R);
  }

  auto E = MaybeRemark.takeError();
  if (!E.isA<EndOfFileError>())
    return E;
  consumeError(std::move(E));
  OF->keep();
  return Error::success();
}

static CommandRegistration FilterReg(&Filter, tryFilter);

} // namespace filter
