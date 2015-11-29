require_relative 'book'
require_relative 'local_cache'
require 'dalli'
require 'json'

  class DatabaseWithCache 
  
    def initialize database, cache  
       @database = database 
       @Remote_cache = cache
       @local_cache = LocalCache.new
    end
    
    def startUp 
    	 @database.startUp 
    end

    def shutDown
      @database.shutDown
    end

    def isbnSearch isbn
      result = nil
      local_copy = @local_cache.get isbn #get isbn of book from local cache and adds it to local_copy
      unless local_copy #run if local_copy is blank 
          memcache_version = @Remote_cache.get "v_#{isbn}" #gets the version from the remote cache and store in memcache_Version
          if memcache_version #if true (something in memecache version)
             memcache_copy = @Remote_cache.get "#{isbn}_#{memcache_version}"  #checks that memcache version is = to remote cache version
             result = Book.from_cache memcache_copy #it then adds that book stored in the memcache to result
             @local_cache.set result.isbn, {book: result, version: memcache_version.to_i} #sets the localcache to isbn of book in result   
          else  #if false(nothing stored in memcached)
             result = @database.isbnSearch isbn  #get the isbn from the database
             if result #if result is true (something in result)
                @Remote_cache.set "v_#{result.isbn}", 1   #set remote cache version (increment)
                @Remote_cache.set "#{result.isbn}_1", result.to_cache #set temote cache to updated isbn book
                @local_cache.set result.isbn, {book: result, version: 1} #updates the local cache 
             end
          end
      else #run if local_copy is not blank 
          memcache_version = @Remote_cache.get "v_#{isbn}" #checks the version of the memcahe is up to date
          if memcache_version.to_i == local_copy[:version] #if memcache_version = to local copy version
             result = local_copy[:book] #then get the book from the local cache
          else #if not = to local copy
             memcache_copy = @Remote_cache.get "#{isbn}_#{memcache_version}" #get the latest version of the memcache
             result = Book.from_cache memcache_copy #result = new book using memcache_copy
             @local_cache.set result.isbn, {book: result, version: memcache_version.to_i} #sets local cache to latest version 
          end
      end
      result #resturn result
    end

    def authorSearch author
        result = nil #variable set to nil
        memcached_isbns = @Remote_cache.get "bks_#{author}" #variable = remotecache(object).get (get isbn list from remote cache)
        if memcached_isbns #if remotecache.get has a value (result is in remote cache)
           isbn_array = memcached_isbns.split(',') #variable = remotecache isbn's are split into an array 
           complex_object_key_parts = isbn_array.map do |isbn| #create an array of isbn's and version's to be used to construct complex data key
              buildISBNVersionString isbn, nil #adds (isbn_1) isbn and version to complex_data_key_parts array.
           end #end loop
           key = "#{author}_#{complex_object_key_parts.join('_')} " #create the key to hold the complex data in
           value = @Remote_cache.get key #get the complex data stored in the remote cache
           if value #complex data is found
              result = JSON.parse value #convert the complex data into a readable format
           else #no complex data is found, must add it to the remote cache
              books = complex_object_key_parts.map do |element| #loop through (isbn_version) array adding next code block to books array
              Book.from_cache(@Remote_cache.get element) #book object created from all the data stored for that (isbn_version)
              end #end loop
              result = computeAuthorReport books #create the complex data from the books array
              @Remote_cache.set key,result.to_json #add new complex key and data to the remote cache
           end #end if statement
        else #end if statement (remotecache does not have value)
          books = @database.authorSearch author #get books array from database
          @Remote_cache.set "bks_#{author}", #set the author key in the remote cache
                         (books.map{|book| book.isbn }).join(',') #join the isbn's for each of the books.
          complex_object_key_parts = books.map do |book| #create complex data key from the books in the books array
               buildISBNVersionString book.isbn, book #call build isbn pass in values isbn, book
          end #end loop
          key = "#{author}_#{complex_object_key_parts.join('_')} " #The key for the complex data.
          result = computeAuthorReport books #create complex data from the books array
          @Remote_cache.set key,result.to_json #add new complex key and data to the remote cache
        end #end loop
        result #return value
    end #end method

    def updateBook book
      @database.updateBook book
      remote_version = @Remote_cache.get "v_#{book.isbn}"
      if remote_version
         new_version = remote_version.to_i + 1
         @Remote_cache.set "v_#{book.isbn}", new_version
         @Remote_cache.set "#{book.isbn}_#{new_version}", book.to_cache
         if @local_cache.get book.isbn
            @local_cache.set book.isbn,  {book: book, version: new_version}
         end
      end
    end

private

   def computeAuthorReport books
       result = { } #create results array
       result['books'] = #create result books array
             books.collect {|book| {'title' => book.title, 'isbn' => book.isbn } } #add elements to book array
        result['value'] = #create result value array
             books.inject(0) {|value,book| value += book.quantity * book.price } # calculate value
        result #return array
    end

    def buildISBNVersionString isbn, book
          isbn_version = @Remote_cache.get  "v_#{isbn}" #get newest version from remote cache
          if isbn_version #if version has value
             "#{isbn}_#{isbn_version}" #return this (isbn)_(version)
          else #if version does not have a value
             @Remote_cache.set "v_#{isbn}", 1 #create a new version for that isbn in remote cache
             (book = @database.isbnSearch isbn) unless book #search the database for abook using isbn unless it was passed into the method
             @Remote_cache.set "#{isbn}_1", book.to_cache #add (isbn)_1 , bookdetails to the remote cache
             "#{isbn}_1" #return this (isbn)_(version)
          end
    end

end 
