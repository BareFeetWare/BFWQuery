Pod::Spec.new do |s|
  s.name         = "BFWQuery"
  s.version      = "1.0.1"
  s.summary      = "Makes the power of SQLite available to Cocoa developers as simple as accessing arrays."
  s.description  = <<-DESC

                1. Makes the power of SQLite available to Cocoa developers as simple as accessing arrays. Initialise a query, then get its resultArray.

                2. Internally manages the array without storing all rows in RAM. BFWQuery creates the objects within a row lazily, when requested. So, whether your query resultArray is 10 rows or 10,000 rows, it shouldn’t take noticeably more memory.
                   DESC
  s.homepage     = "https://github.com/BareFeetWare/BFWControls"
  s.license      = { :type => "MIT", :text => <<-LICENSE
        Copyright (c) 2015 BareFeetWare

        Use as you like, but keep the (c) BareFeetWare in the header and include “Includes BFWQuery class by BareFeetWare” in your app’s info panel or credits.

        Many thanks to Gus Mueller for FMDB and Dr Richard Hipp for SQLite.
                LICENSE
             }
  s.authors      = { "Tom Brodhurst-Hill" => "developer@barefeetware.com" }
  s.platform     = :ios, "8.0"
  s.source       = { :git => "https://github.com/BareFeetWare/BFWQuery.git", :tag => "#{s.version}" }

  s.requires_arc = true

  s.source_files = "BFWQuery/Modules/BFWQuery/**/*.{h,m}"
  s.library = "sqlite3"
  s.dependency "FMDB", "~> 2.6"
end
