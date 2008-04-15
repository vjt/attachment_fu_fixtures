module Mynyml
  module AttachmentFuFixtures
    class AttachmentFileNotFound < ArgumentError # :nodoc:
    end

    # In order to set model ids, fixtures are inserted manually. The following
    # overrides the insertion to trigger some attachment_fu functionality before
    # it gets added to the db
    def insert_fixture_with_attachment(fixture, table_name)
      if (klass = fixture.model_class) && klass.instance_methods.include?('uploaded_data=')

        fixture   = fixture.to_hash
        full_path = fixture.delete('attachment_file')
        mime_type = fixture.delete('content_type') || guess_mime_type(full_path) || 'image/png'
        assert_attachment_exists(full_path)

        require 'action_controller/test_process'
        klass.destroy_all
        attachment = klass.new
        attachment.uploaded_data = ActionController::TestUploadedFile.new(full_path, mime_type)
        attachment.instance_variable_get(:@attributes)['id'] = fixture['id'] #pwn id
        attachment.valid? #trigger validation for the callbacks
        attachment.send(:after_process_attachment) #manually call after_save callback

        fixture = Fixture.new(attachment.attributes.update(fixture), klass)
      end
      insert_fixture_without_attachment(fixture, table_name)
    end
    
    private
      # if content_type isn't specified, attempt to use file(1)
      # todo: confirm that `file` silently fails when not available
      # todo: test on win32
      def guess_mime_type(path)
        return nil
        #test behaviour on windows before using this
        type = `file #{path} -ib 2> /dev/null`.chomp
        type.blank? ? nil : type
      end

      def assert_attachment_exists(path)
        unless path && File.exist?(path)
          raise AttachmentFileNotFound, "Couldn't find attachment_file #{path}"
        end
      end
  end
end
