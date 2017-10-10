
module Rake
  VERSION = '10.4.2'
end

require 'rake/version'

RAKEVERSION = Rake::VERSION

require 'rbconfig'
require 'fileutils'
require 'singleton'
require 'monitor'
require 'optparse'
require 'ostruct'

require 'rake/ext/module'
require 'rake/ext/string'
require 'rake/ext/time'

require 'rake/win32'

require 'rake/linked_list'
require 'rake/cpu_counter'
require 'rake/scope'
require 'rake/task_argument_error'
require 'rake/rule_recursion_overflow_error'
require 'rake/rake_module'
require 'rake/trace_output'
require 'rake/pseudo_status'
require 'rake/task_arguments'
require 'rake/invocation_chain'
require 'rake/task'
require 'rake/file_task'
require 'rake/file_creation_task'
require 'rake/multi_task'
require 'rake/dsl_definition'
require 'rake/file_utils_ext'
require 'rake/file_list'
require 'rake/default_loader'
require 'rake/early_time'
require 'rake/late_time'
require 'rake/name_space'
require 'rake/task_manager'
require 'rake/application'
require 'rake/backtrace'

$trace = false


FileList = Rake::FileList
RakeFileUtils = Rake::FileUtilsExt
