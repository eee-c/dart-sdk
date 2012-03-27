// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library('leg');

#import('../../uri/uri.dart');

#import('colors.dart');
#import('elements/elements.dart');
#import('native_handler.dart', prefix: 'native');
#import('scanner/scanner_implementation.dart');
#import('scanner/scannerlib.dart');
#import('ssa/ssa.dart');
#import('string_validator.dart');
#import('tree/tree.dart');
#import('util/characters.dart');
#import('util/util.dart');

#source('compile_time_constants.dart');
#source('compiler.dart');
#source('diagnostic_listener.dart');
#source('emitter.dart');
#source('enqueue.dart');
#source('namer.dart');
#source('native_emitter.dart');
#source('operations.dart');
#source('resolver.dart');
#source('script.dart');
#source('tree_validator.dart');
#source('typechecker.dart');
#source('universe.dart');
#source('warnings.dart');

void unreachable() {
  throw const Exception("Internal Error (Leg): UNREACHABLE");
}
