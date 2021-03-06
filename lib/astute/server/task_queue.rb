#    Copyright 2013 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

require 'thread'

module Astute
  module Server

    class TaskQueue
      include Enumerable

      attr_reader :current_task_id
      attr_reader :current_task_method

      def initialize
        @queue = []
        @semaphore = Mutex.new
        @current_task_id = nil
        @current_task_method = nil
      end

      def add_task(data)
        @semaphore.synchronize { data.compact.each { |t| @queue << t } }
      end

      def replace_task(replacing_task_id, new_task_data)
        @semaphore.synchronize do
          @queue.map! { |x| find_task_id(x) == replacing_task_id ? new_task_data : x }.flatten!
        end
      end

      def remove_task(replacing_task_id)
        replace_task(replacing_task_id, nil)
      end

      def clear_queue
        @semaphore.synchronize { @queue.map! { |x| nil } }
      end

      def task_in_queue?(task_id)
        @semaphore.synchronize { @queue.find { |t| find_task_id(t) == task_id } }
      end

      def each(&block)
        @queue.each do |task|
          @semaphore.synchronize do
            next if task.nil?
            @current_task_id = find_task_id(task)
            @current_task_method = find_task_method(task)
          end

          if block_given?
            block.call task
          else
            yield task
          end
        end
      ensure
        @semaphore.synchronize do
          @current_task_id = nil
          @current_task_method = nil
        end
      end

      private

      def find_task_id(data)
        data && data['args'] && data['args']['task_uuid'] ? data['args']['task_uuid'] : nil
      end

      def find_task_method(data)
        data && data['method']
      end

    end

  end #Server
end #Astute