// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library('leg_apiimpl');

#import('leg.dart', prefix: 'leg');
#import('elements/elements.dart', prefix: 'leg');
#import('tree/tree.dart', prefix: 'leg');
#import('ssa/tracer.dart', prefix: 'ssa');
#import('../lang.dart', prefix: 'frog');
#import('api.dart');
#import('../../uri/uri.dart');

class Compiler extends leg.Compiler {
  ReadUriFromString provider;
  DiagnosticHandler handler;
  Uri libraryRoot;
  List<String> options;
  bool mockableLibraryUsed = false;

  Compiler(this.provider, this.handler, this.libraryRoot, this.options)
    : super.withCurrentDirectory(null, tracer: new ssa.HTracer());

  leg.LibraryElement scanBuiltinLibrary(String filename) {
    Uri uri = libraryRoot.resolve(filename);
    leg.LibraryElement library = scanner.loadLibrary(uri, null);
    return library;
  }

  void log(message) {
    handler(null, null, null, message, false);
  }

  leg.Script readScript(Uri uri, [leg.ScriptTag node]) {
    if (uri.scheme == 'dart') {
      uri = translateDartUri(uri, node);
    }
    String text = "";
    try {
      // TODO(ahe): We expect the future to be complete and call value
      // directly. In effect, we don't support truly asynchronous API.
      text = provider(uri).value;
    } catch (var exception) {
      cancel("${uri}: $exception", node: node);
    }
    frog.SourceFile sourceFile = new frog.SourceFile(uri.toString(), text);
    return new leg.Script(uri, sourceFile);
  }

  translateDartUri(Uri uri, leg.ScriptTag node) {
    String uriName = uri.toString();
    // TODO(ahe): Clean this up.
    if (uriName == 'dart:dom') {
      mockableLibraryUsed = true;
      return libraryRoot.resolve('../../../client/dom/frog/dom_frog.dart');
    } else if (uriName == 'dart:html') {
      mockableLibraryUsed = true;
      return libraryRoot.resolve('../../../client/html/frog/html_frog.dart');
    } else if (uriName == 'dart:json') {
      return libraryRoot.resolve('../../../json/json.dart');
    } else if (uriName == 'dart:isolate') {
      return libraryRoot.resolve('../../../isolate/isolate_leg.dart');
    } else if (uriName == 'dart:io') {
      mockableLibraryUsed = true;
      return libraryRoot.resolve('io.dart');
    } else if (uriName == 'dart:utf') {
      return libraryRoot.resolve('../../../utf/utf.dart');
    } else if (uriName == 'dart:uri') {
      return libraryRoot.resolve('../../../uri/uri.dart');
    }
    reportError(node, "library not found $uriName");
  }

  bool run(Uri uri) {
    bool success = super.run(uri);
    for (final task in tasks) {
      log('${task.name} took ${task.timing}msec');
    }
    return success;
  }

  void reportDiagnostic(leg.SourceSpan span, String message, bool fatal) {
    if (span === null) {
      handler(null, null, null, message, fatal);
    } else {
      handler(span.uri, span.begin, span.end, message, fatal);
    }
  }

  bool get isMockCompilation() {
    return mockableLibraryUsed
      && (options.indexOf('--allow-mock-compilation') !== -1);
  }
}
