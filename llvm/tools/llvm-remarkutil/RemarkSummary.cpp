//===- RemarkSummary.cpp --------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Generic tool to produce remark summaries
//
//===----------------------------------------------------------------------===//

#include "RemarkUtilHelpers.h"
#include "RemarkUtilRegistry.h"

#include "llvm/ADT/StringExtras.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/Regex.h"
#include <algorithm>
#include <list>

using namespace llvm;
using namespace remarks;
using namespace llvm::remarkutil;

namespace instructionmix {

static cl::SubCommand Summary("summary", "Produce remark summaries");

INPUT_FORMAT_COMMAND_LINE_OPTIONS(Summary)
INPUT_OUTPUT_COMMAND_LINE_OPTIONS(Summary)

struct FunctionSummary {
  std::optional<RemarkLocation> Loc;
  StringMap<size_t> Stats;
  struct Cost {
    int Cost = 0;
    int Threshold = 0;
    std::optional<RemarkLocation> Loc;

    int getProfit() { return Threshold - Cost; }
  };
  std::optional<Cost> LeastProfitable;
  std::optional<Cost> MostProfitable;
};

static Error trySummary() {
  auto MaybeOF = getOutputFileForRemarks(OutputFileName, Format::YAML);
  if (!MaybeOF)
    return MaybeOF.takeError();

  auto OF = std::move(*MaybeOF);
  auto MaybeBuf = getInputMemoryBuffer(InputFileName);
  if (!MaybeBuf)
    return MaybeBuf.takeError();
  auto MaybeParser = createRemarkParser(InputFormat, (*MaybeBuf)->getBuffer());
  if (!MaybeParser)
    return MaybeParser.takeError();

  auto MaybeSerializer = createRemarkSerializer(Format::YAML, OF->os());
  if (!MaybeSerializer)
    return MaybeSerializer.takeError();

  auto &Parser = **MaybeParser;
  auto &Serializer = **MaybeSerializer;
  auto MaybeRemark = Parser.next();
  StringMap<FunctionSummary> Summaries;
  for (; MaybeRemark; MaybeRemark = Parser.next()) {
    Remark &Remark = **MaybeRemark;
    if (Remark.PassName == "inline") {
      auto *CalleeArg = Remark.getArgByKey("Callee");
      if (!CalleeArg)
        continue;
      auto &FSum = Summaries[CalleeArg->Val];
      ++FSum.Stats[Remark.RemarkName];
      if (!FSum.Loc)
        FSum.Loc = CalleeArg->Loc;

      auto *CostArg = Remark.getArgByKey("Cost");
      auto *ThresholdArg = Remark.getArgByKey("Threshold");
      if (CostArg && ThresholdArg) {
        auto CostVal = CostArg->getValAsInt();
        auto ThresholdVal = ThresholdArg->getValAsInt();
        if (!CostVal || !ThresholdVal)
          continue;
        FunctionSummary::Cost NewCost{*CostVal, *ThresholdVal, Remark.Loc};
        ;
        if (!FSum.LeastProfitable) {
          FSum.LeastProfitable = NewCost;
        } else {
          if (FSum.LeastProfitable->getProfit() > NewCost.getProfit()) {
            if (!FSum.MostProfitable) {
              FSum.MostProfitable = FSum.LeastProfitable;
              FSum.LeastProfitable = NewCost;
            } else if (FSum.MostProfitable->getProfit() < NewCost.getProfit()) {
              FSum.MostProfitable = NewCost;
            }
          }
        }
      }
    }
  }

  std::list<std::string> Strs;
  for (auto &FSum : Summaries) {
    remarks::Remark R;
    if (FSum.second.Stats.empty())
      continue;
    R.FunctionName = FSum.first();
    R.PassName = "remark-summary";
    R.RemarkName = "inline";
    R.RemarkType = remarks::Type::Analysis;
    R.Loc = FSum.second.Loc;
    R.Args.emplace_back("String", "Incoming Calls ");
    bool First = true;
    for (auto &E : FSum.second.Stats) {
      if (!First)
        R.Args.emplace_back("String", ", ");
      R.Args.emplace_back("String", E.first());
      R.Args.emplace_back("String", ": ");
      R.Args.emplace_back(E.first(), Strs.emplace_back(itostr(E.second)));
      First = false;
    }
    if (FSum.second.LeastProfitable) {
      R.Args.emplace_back("String", "\nLeast profitable Cost/Threshold: ");
      R.Args.emplace_back(
          "LeastProfitCost",
          Strs.emplace_back(itostr(FSum.second.LeastProfitable->Cost)),
          FSum.second.LeastProfitable->Loc);
      R.Args.emplace_back("String", "/");
      R.Args.emplace_back(
          "LeastProfitThreshold",
          Strs.emplace_back(itostr(FSum.second.LeastProfitable->Threshold)));
    }
    if (FSum.second.MostProfitable) {
      R.Args.emplace_back("String", "\nMost profitable Cost/Threshold: ");
      R.Args.emplace_back(
          "MostProfitCost",
          Strs.emplace_back(itostr(FSum.second.MostProfitable->Cost)),
          FSum.second.MostProfitable->Loc);
      R.Args.emplace_back("String", "/");
      R.Args.emplace_back(
          "MostProfitThreshold",
          Strs.emplace_back(itostr(FSum.second.MostProfitable->Threshold)));
    }
    Serializer.emit(R);
  }

  auto E = MaybeRemark.takeError();
  if (!E.isA<EndOfFileError>())
    return E;
  consumeError(std::move(E));
  OF->keep();
  return Error::success();
}

static CommandRegistration SummaryReg(&Summary, trySummary);

} // namespace instructionmix
