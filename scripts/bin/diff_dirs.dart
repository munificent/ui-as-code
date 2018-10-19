// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:io';

import 'package:path/path.dart' as p;

final headerPattern = RegExp(r"^(---|\+\+\+) (\S+)");

/// These are the known expected differences between the baseline and parsed
/// stripped corpus.
final knownBad = [
  // Hanging returns.
  "flutter/packages/flutter_tools/lib/src/base/utils.dart",
  "flutter/packages/flutter_tools/lib/src/commands/config.dart",
  "flutter/packages/flutter_tools/lib/src/commands/fuchsia_reload.dart",
  "flutter/packages/flutter_tools/lib/src/runner/flutter_command_runner.dart",
  "packages/angular_components-0.10.0/lib/src/utils/angular/scroll_host/sticky_controller_impl.dart",
  "packages/appengine-0.5.1/test/integration/raw_datastore_test_impl.dart",
  "packages/dacsslide-0.3.1+1/lib/pcss_builder.dart",
  "packages/flutter_webrtc-0.0.1/example/lib/src/basic_sample/data_channel_sample.dart",
  "packages/flutter_webrtc-0.0.1/example/lib/src/basic_sample/loopback_sample.dart",
  "sdk/pkg/compiler/lib/src/js_emitter/program_builder/field_visitor.dart",
  "packages/rx_command-4.0.1/example/lib/listview.dart",
  "packages/postgresql2-0.5.1+1/lib/src/mock/mock.dart",
  "packages/over_react-1.27.0/lib/src/transformer/text_util.dart",
  "packages/icetea_studio_core-0.0.2/lib/ui/widgets/inputs/inline_add_input.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/analytic_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/application_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/assign_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/business_activity_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/category_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/comment_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/contribution_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/delegate_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/device_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/export_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/facebook_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/feedback_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/image_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/issue_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/log_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/login_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/logo_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/member_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/membership_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/operation_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/organization_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/person_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/place_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/register_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/relationship_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/report_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/request_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/review_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/review_request_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/service_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/state_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/tracking_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/transition_api.dart",
  "packages/keyclic_sdk_api-1.28.4/lib/api/webhook_api.dart",

  // Split after local variable type.
  "packages/dio-1.0.6/example/requestInterceptors.dart",
  "packages/dio-1.0.6/test/dio_test.dart",
  "packages/googleapis-0.52.0/test/cloudiot/v1_test.dart",
  "packages/googleapis_beta-0.47.0/test/toolresults/v1beta3_test.dart",
  "packages/over_react-1.27.0/test/over_react/util/class_names_test.dart",

  // Empty statement in control flow.
  "sdk/sdk/lib/_http/http_date.dart",
  "sdk/runtime/observatory/tests/service/async_generator_breakpoint_test.dart",
  "sdk/runtime/observatory/lib/src/cli/command.dart",
  "sdk/runtime/observatory/lib/src/service/object.dart",
  "sdk/pkg/dart2js_tools/bin/show_inline_data.dart",
  "packages/stream-2.0.2/lib/src/rspc/tag_util.dart",
  "packages/stream-2.0.2/lib/src/rspc/tag.dart",
  "packages/stream-2.0.2/lib/src/rspc/compiler.dart",
  "packages/mammouth-4.0.0-beta/lib/src/syntactic/lexer.dart",
  "sdk/runtime/observatory/lib/object_graph.dart",
  "sdk/runtime/observatory/tests/service/evaluate_in_async_star_activation_test.dart",
  "sdk/runtime/observatory/tests/service/evaluate_in_sync_star_activation_test.dart",
];

final falsePositives = [
  // Split after type in field or top-level variable.
  "packages/access-1.0.1+2/lib/access.dart",
  "packages/access-1.0.1+2/lib/dbtool.dart",
  "packages/angular_components-0.10.0/lib/src/material_tree/material_tree_dropdown.dart",
  "packages/entity-1.0.1/lib/oid.dart",
  "packages/flutter_blue-0.4.1/lib/src/bluetooth_characteristic.dart",
  "packages/flutter_section_table_view-1.0.1/lib/flutter_section_table_view.dart",
  "packages/googleapis-0.52.0/test/analytics/v3_test.dart",
  "packages/googleapis-0.52.0/test/content/v2_test.dart",
  "packages/googleapis-0.52.0/test/content/v2sandbox_test.dart",
  "packages/googleapis-0.52.0/test/dialogflow/v2_test.dart",
  "packages/googleapis-0.52.0/test/pagespeedonline/v1_test.dart",
  "packages/googleapis-0.52.0/test/pagespeedonline/v4_test.dart",
  "packages/googleapis-0.52.0/test/plus/v1_test.dart",
  "packages/googleapis-0.52.0/test/plusdomains/v1_test.dart",
  "packages/googleapis-0.52.0/test/videointelligence/v1_test.dart",
  "packages/googleapis_beta-0.47.0/test/dialogflow/v2beta1_test.dart",
  "packages/mysql1-0.15.2/lib/constants.dart",
  "packages/rikulo_commons-3.0.4/lib/src/mirrors/classes.dart",
  "packages/rikulo_commons-3.0.4/lib/src/util/xmls.dart",
  "packages/sembast-1.9.5/lib/sembast_memory.dart",
  "packages/sqljocky5-2.2.0/lib/constants.dart",
  "sdk/pkg/analysis_server/lib/protocol/protocol_constants.dart",
  "sdk/pkg/analyzer/lib/src/error/codes.dart",
  "sdk/pkg/analyzer/lib/src/generated/engine.dart",
  "sdk/pkg/compiler/lib/src/js_model/closure.dart",

  // Prototype incorrectly treats "factory" as keyword.
  "packages/angular_compiler-0.4.1/lib/src/analyzer/reflector.dart",
  "packages/idb_shim-1.7.0/test/idb_test_common.dart",
  "packages/pointycastle-0.11.1/lib/src/registry/registry.dart",
  "packages/sembast-1.9.5/test/test_common.dart",
  "packages/sqflite-0.12.2+1/lib/src/database.dart",
  "packages/sqflitezjl-0.11.1/lib/src/database.dart",
  "packages/test-1.3.4/lib/src/runner/configuration/reporters.dart",
  "packages/over_react-1.27.0/lib/src/transformer/declaration_parsing.dart",

  // Prototype incorrectly treats "async" as keyword.
  "packages/audiofile_plugin-0.0.4/lib/audiofile_plugin.dart",

  // Prototype incorrectly treats "get" or "set" as keyword.
  "packages/googleapis-0.52.0/lib/serviceconsumermanagement/v1.dart",
  "packages/googleapis-0.52.0/lib/servicemanagement/v1.dart",
  "packages/googleapis-0.52.0/lib/serviceusage/v1.dart",
  "packages/googleapis-0.52.0/lib/serviceuser/v1.dart",
  "packages/googleapis_beta-0.47.0/lib/dataflow/v1b3.dart",
  "packages/json_serializable-1.5.1/test/kitchen_sink/kitchen_sink_interface.dart",

  // Whitespace moved around ";" and comments.
  "packages/dartdoc-0.24.0/lib/src/model.dart",
  "packages/linter-0.1.69/test/rules/avoid_bool_literals_in_conditional_expressions.dart",
  "packages/linter-0.1.69/test/rules/avoid_js_rounded_ints.dart",
  "packages/linter-0.1.69/test/rules/avoid_types_as_parameter_names.dart",
  "packages/slickdart-0.2.0/example/sample/gdoc_header.dart",
  "sdk/sdk/lib/html/html_common/conversions_dart2js.dart",

  // Had empty statement in previous code.
  "packages/dawo-0.0.78/lib/src/box_serve.dart",

  // Deliberate syntax error in code.
  "sdk/runtime/observatory/tests/service/developer_extension_test.dart",
  "packages/linter-0.1.69/test/_data/synthetic/synthetic.dart",

  // Prototype incorrectly treats list literal as index operator.
  "packages/linter-0.1.69/test/rule_test.dart",

  // Empty statement in control flow, but for linter test.
  "packages/linter-0.1.69/test/rules/avoid_empty_else.dart",
  "packages/linter-0.1.69/test/rules/empty_statements.dart",

  // Treats two strings as adjacent, but not real code.
  "packages/linter-0.1.69/test/rules/prefer_interpolation_to_compose_strings.dart",
];

/// Diffs two directories and then pretties up the output taking into account
/// the special formatter error comments produced by the hacked dart_style.
void main(List<String> arguments) {
  var from = arguments[0];
  var to = arguments[1];

  var diffs = 0;
  var ignored = 0;
  var knownFalsePositives = 0;
  var knownFailures = 0;

  Diff diff;
  String fromPath;

  finishDiff() {
    if (diff == null) return;

    // Whitelist the known ones.
    for (var path in knownBad) {
      if (diff.fromPath.endsWith(path)) {
        knownFailures++;
        return;
      }
    }

    for (var path in falsePositives) {
      if (diff.fromPath.endsWith(path)) {
        knownFalsePositives++;
        return;
      }
    }

    // If the only differences are whitespace, ignore them.
    var skipDiff = true;
    for (var line in diff.lines) {
      if ((line.startsWith("-") || line.startsWith("+")) &&
          line.trim().length > 1 &&
          line.substring(1).trim() != ";") {
        skipDiff = false;
        break;
      }
    }

    if (skipDiff) {
      ignored++;
      return;
    }

    // If the only differences are moved semicolons on lines containing
    // comments, it's because it moved the semicolon before the comment.
    // Ignore those.
    var removes = <String>[];
    var adds = <String>[];
    for (var line in diff.lines) {
      if (line.startsWith("-")) removes.add(line);
      if (line.startsWith("+")) adds.add(line);
    }

    if (removes.isNotEmpty && removes.length == adds.length) {
      skipDiff = true;

      for (var i = 0; i < removes.length; i++) {
        var remove = removes[i];
        var add = adds[i];
        if ((remove.contains("//") || remove.contains("/*")) &&
            remove.substring(1).replaceAll(";", "").replaceAll(" ", "") ==
                add.substring(1).replaceAll(";", "").replaceAll(" ", "")) {
          // We can ignore this.
        } else {
          // Got a real diff.
          skipDiff = false;
          break;
        }
      }

      if (skipDiff) {
        ignored++;
        return;
      }
    }

    var fromParts = p.split(diff.fromPath);
    var toParts = p.split(diff.toPath);

    var parts = <String>[];
    for (var i = 0; i < fromParts.length; i++) {
      if (fromParts[i] != toParts[i]) {
        parts.add("(${fromParts[i]}|${toParts[i]})");
      } else if (parts.isNotEmpty) {
        parts.add(fromParts[i]);
      }
    }

    var errorInFrom = diff.lines.any((line) =>
        line.startsWith("-") &&
        line.contains(
            "Could not format because the source could not be parsed"));
    var errorInTo = diff.lines.any((line) =>
        line.startsWith("+") &&
        line.contains(
            "Could not format because the source could not be parsed"));
    var errorInBoth = diff.lines.any((line) => line.startsWith(
        " // Could not format because the source could not be parsed"));

    // Ignore differences if both before and after had compile errors. This is
    // usually just the different file name or error location.
    if (errorInBoth) {
      ignored++;
      return;
    }

    var unionPath = p.joinAll(parts);
    print(unionPath);

    if (errorInFrom && errorInTo) {
      print("Error in both:");
      for (var line in diff.lines) print(line);
    } else if (errorInFrom) {
      print("Error in from:");
      for (var line in diff.lines) {
        if (line.startsWith("-")) print(line.substring(4));
      }
    } else if (errorInTo) {
      print("Error in to:");
      for (var line in diff.lines) {
        if (line.startsWith("+")) print(line.substring(4));
      }
    } else {
      for (var line in diff.lines) print(line);
    }

    print("");
    diffs++;
  }

  var stdout = Process.runSync("diff", ["-ru", from, to]).stdout as String;
  for (var line in stdout.split("\n")) {
    var match = headerPattern.firstMatch(line);
    if (match != null) {
      if (line.startsWith("---")) {
        fromPath = match.group(2);
      } else {
        finishDiff();
        diff = Diff(fromPath, match.group(2));
      }
    } else if (line.startsWith("-") && !line.startsWith("---") ||
        line.startsWith("+") && !line.startsWith("+++") ||
        line.startsWith(" ")) {
      diff.lines.add(line);
    }
  }

  finishDiff();
  print("$diffs differences, $ignored ignored, $knownFailures failures, "
      "$knownFalsePositives false positives");
}

class Diff {
  final String fromPath;
  final String toPath;

  final List<String> lines = [];

  Diff(this.fromPath, this.toPath);
}
