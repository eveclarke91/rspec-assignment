require_relative "./database_with_cache.rb"
require "rspec/mocks"
require 'pp'

describe DatabaseWithCache do
  before(:each) do #before each test create a book create all the databases 
      @book1111 = Book.new('1111','title 1','author 1',12.99, 'Programming', 20 ) # new book
      @memcached_mock = double()
      @database_mock = double()      
      @local_cache_mock = double()      
      @target = DatabaseWithCache.new @database_mock, @memcached_mock      
      #@target.instance_variable_set "@local_cache", @local_cache_mock
      @local_cache_mock = @target.instance_variable_get "@local_cache"

      #@local_cache_mock = double()
      #@local_cache_mock = double(LocalCache)
    end

    describe "#isbnSearch" do
      context "Given the book ISBN is valid" do

        context "and it is not in the local cache" do

          context "nor in the remote cache" do
            it "should read it from the d/b and add it to the remote cache" do
                 expect(@memcached_mock).to receive(:get).with('v_1111').and_return nil #this checks that its not in the remote cache and returns nil
                 expect(@memcached_mock).to receive(:set).with('v_1111',1) #set a new version in remote cache
                 expect(@memcached_mock).to receive(:set).with('1111_1',@book1111.to_cache) #setting book isbn to remote cache
                 expect(@database_mock).to receive(:isbnSearch).with('1111'). #request book isbn from database
                                and_return(@book1111) #and return book1111
                 result = @target.isbnSearch('1111') #adds the book returned to result
                 expect(result).to be @book1111 #checks book in result matches book 1111
                 #pp @local_cache_mock
                 #pp @target
               end
             end

             context "but it is in the remote cache" do
              it "should use the remote cache version and add it to local cache" do
                 expect(@database_mock).to_not receive(:isbnSearch) # do not check database                 
                 expect(@memcached_mock).to receive(:get).with('v_1111').and_return 1 #checks version in memecache, increments version
                 expect(@memcached_mock).to receive(:get).with('1111_1'). #retrieves book
                                                    and_return @book1111.to_cache #returns book to local cache
                 result = @target.isbnSearch('1111') #adds book to result
                # pp @target
                expect(result).to eq @book1111 
                 #pp @local_cache_mock
                 #pp @target
               end
             end
           end
           context "it is in the local cache" do
             context "and up to date with the remote cache" do
              it "should use the local cache version" do

                #not in database
                expect(@database_mock).to_not receive(:isbnSearch)
                expect(@local_cache_mock).to receive(:get).with('1111').and_return({book: @book1111, version: 1})
                expect(@memcached_mock).to receive(:get).with('v_1111').and_return 1 #this checks that its not in the remote cache and returns nil
                
                @local_book = @local_cache_mock.get('1111')
                @remote_version = @memcached_mock.get('v_1111')
                @local_version = @local_book[:version]
                expect(@local_version).to eq @remote_version
                expect(@local_book[:book]).to eq @book1111

              end 
            end
            context "not up to date with remote cache" do
              it " should use remote cache version and update local cache" do
                expect(@database_mock).to_not receive(:isbnSearch)                          

                #set remotecache to version 2
                  #@new_book = Book.new('1111','title 1','Jimbob',12.99, 'Programming', 20 )
                  #@memcached_mock.set('v_1111', 2)
                  #@memcached_mock.set('1111_2', @new_book.to_cache)

                  #@new_book = Book.new('1111','title 1','Jimbob',12.99, 'Programming', 20 )
                  #expect(@database_mock).to receive(:updateBook).with(@new_book)
                  #expect(@memcached_mock).to receive(:get).with('v_1111').and_return 1
                  #expect(@memcached_mock).to receive(:set).with('v_1111', 2 )
                  #expect(@memcached_mock).to receive(:set).with('1111_2', @new_book.to_cache)

                  #expect(@memcached_mock).to receive(:set).with('v_1111',2)
                  #@memcached_mock.set('v_1111',2) #set a new version in remote cache
                  
                  #expect(@memcached_mock).to receive(:get).with('v_1111').and_return 2    
                  #@memcached_mock.set('1111_2' ,@book1111.to_cache) #setting book isbn to remote cache

                #get local version 
                expect(@local_cache_mock).to receive(:get).with('1111').and_return({book: @book1111, version: 1})
                @local_book = @local_cache_mock.get('1111')
                @local_version = @local_book[:version]
                #get remote version
                expect(@memcached_mock).to receive(:get).with('v_1111').and_return 1 #should be 2
                @remote_version = @memcached_mock.get('v_1111') #should be 2

                #expect versions to be different
                expect(@local_version).to eq @remote_version #.to_not

                #get remote cache data and transfer it to local cache.
                        
              end
            end
          end      
        end

        context "Given ISBN is not valid" do
          it "it should not be found in any database and return nil" do
            expect(@local_cache_mock).to receive(:get).with('2222').and_return nil
            expect(@memcached_mock).to receive(:get).with('v_2222').and_return nil
            expect(@database_mock).to receive(:isbnSearch).with('2222').and_return nil
            result = @target.isbnSearch('2222')
            expect(result).to be nil
          end
        end 
      end  

    describe "#updateBook" do
       before(:each) do
        @updatedBook = Book.new('1111','title 1','Jim',30.99, 'Programming', 20 )        
        #expect(@database_mock).to receive(:updateBook).with(@updatedBook)
       end
      context "Given that a book has a valid ISBN" do

        context "and is in the remote cache"do
          it " then it should update the book to the new version"do
            
            #get remote version
            #@updatedBook = Book.new('1111','title 1','Jim',30.99, 'Programming', 20 ) 
            expect(@database_mock).to receive(:updateBook).with(@updatedBook)

            expect(@memcached_mock).to receive(:get).with('v_1111').and_return 1
            expect(@memcached_mock).to receive(:set).with('v_1111', 2 )
            expect(@memcached_mock).to receive(:set).with('1111_2', @updatedBook.to_cache)

            #expect(@local_cache_mock).to receive(:get).and_return nil
            @target.updateBook @updatedBook

          end
        end
        context "and is in the local cache" do
          context "and is not up to date with remote cache"do
            it "then update version in local cache with remote cache version" do

              expect(@database_mock).to receive(:updateBook).with(@updatedBook)
              expect(@memcached_mock).to receive(:get).with('v_1111').and_return( 1 )
              expect(@memcached_mock).to receive(:set).with('v_1111', 2 )
              expect(@memcached_mock).to receive(:set).with('1111_2', @updatedBook.to_cache)
              expect(@local_cache_mock).to receive(:get).with('1111').and_return({book: @book1111, version: 1})
              expect(@local_cache_mock).to receive(:set).with('1111', {book: @updatedBook, version: 2})
                    
              @target.updateBook @updatedBook

            end
          end
        end
      end
      context "Given that the isbn is invalid" do
        it "should not update any book" do
          expect(@database_mock).to receive(:updateBook).with(@updatedBook)
          expect(@memcached_mock).to receive(:get).with('v_1111').and_return nil            
          @target.updateBook @book1111
        end
      end
    end
    describe "#authorSearch" do
      before(:each) do
        @newbook1 = Book.new('1112','newbook1','Jim',17.95, 'How to get over your fear of Ruby', 14 )
        @newbook2 = Book.new('1113','newbook2','Jim',14.95, 'How to live with it anyway', 15 )
        @newbook3 = Book.new('1114','newbook3','Jim',25.45, 'How to make chili sauce', 26 )
        #@complex = String.new("{\"books\":[{\"title\":\"newbook1\",\"isbn\":\"1112\"},{\"title\":\"newbook2\",\"isbn\":\"1113\"},{\"title\":\"newbook3\",\"isbn\":\"1114\"}],\"value\":1137.25}")
        @complex = String.new('{"books":[{"title":"newbook1","isbn":"1112"},{"title":"newbook2","isbn":"1113"},{"title":"newbook3","isbn":"1114"}],"value":1137.25}')
      
      end
      context "Given that the author is valid" do
        context "found isbn's for this author in the remote cache," do
          context "found complex data for this autor in the remote cache" do
              it "should use the remote version of data for this author" do
                expect(@database_mock).to receive(:authorSearch).with('Jim').and_return [@newbook1, @newbook2, @newbook3]
                expect(@memcached_mock).to receive(:get).with('bks_Jim')
                expect(@memcached_mock).to receive(:set).with("Jim_1112_1_1113_1_1114_1 ", @complex)                
                expect(@memcached_mock).to receive(:set).with("bks_Jim", '1112,1113,1114')

                expect(@target).to receive(:buildISBNVersionString).with('1112', @newbook1).and_return '1112_1'
                expect(@target).to receive(:buildISBNVersionString).with('1113', @newbook2).and_return '1113_1'
                expect(@target).to receive(:buildISBNVersionString).with('1114', @newbook3).and_return '1114_1'

                result = @target.authorSearch 'Jim'
                expect(result).to eq JSON.parse @complex

                #expect(@database_mock).to receive(:authorSearch).with('Jim')

                #expect(@database_mock).to receive(:authorSearch).with('Jim')
                #expect(@memcached_mock).to receive(:get).with('Jim')
                #result = @target.authorSearch 'Jim'
              end
          end
          context "no complex data found for this author in the remote cache" do
              it "should generate a report from the isbns found and put the data into the remote cache" do
              
              end
          end
        end
        context "no isbn's found for this author in the remote cache" do
            it "should generate a books array from the database and generate a report from the isbns found and put the data into the remote cache" do
            
            end
        end
      end
      context "Given that the author is invalid" do
        it "shouldnt generate a report at all" do
          #expect(@memcached_mock).to receive(:get).with('bks_someauthor')
          #expect(@database_mock).to receive(:authorSearch).with('someauthor').and_return []
          #expect(@memcached_mock).to receive(:set).with('bks_someauthor', ""), []
          #result = @target.authorSearch "someauthor"
          #expect(result).to eq Hash["books"=> [], "value"=> 0]
        
        end
      end
    end
end
