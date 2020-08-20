require 'net/http'
require 'nokogiri'
require 'fileutils'
require 'json'

module Yankee
  class Index
    # 引数のpathにHTMLファイルが無い,又はDownload後指定時間経過していたら引数のURLからDownloadする
    def self.file_exist(path,url)
      # pathにファイルが存在しない場合urlから取得した内容で書き込み
      write_file(path, read_website(url)) if !(File.exist?(path))
      # pathにあるファイルの作成時刻が現在時刻の7日以前の場合urlから取得した内容で書き込み
      write_file(path, read_website(url)) if 86400 < (Time.now - File::Stat.new(path).mtime)
      # 現在時刻はTime.now pathの最終更新日時 File::Stat.new(path).mtime 差 "#{Time.now - File::Stat.new(path).mtime}秒"
    end
    
    # 引数のURLからHTMLファイルを取得
    def self.read_website(url)
      Net::HTTP.get(URI(url))
    end

    # 引数のファイル名と内容で保存
    def self.write_file(path, text)
      File.open(path, 'w') { |file| file.write(text) }
    end

    # 引数のpathからnokogiriのパーサーを通してインスタンス生成
    def self.nokogiri(path)
      Nokogiri::HTML.parse(read_file(path), nil, 'utf-8')
    end
    
    # 引数のpathのファイルを開く
    def self.read_file(path)
      File.read(path) 
    end
    
    # 引数のXPathと属性でvalueの配列を返す
    def self.get_attr_value(doc,xpath,attr)
      doc.xpath(xpath).map { |node|
        node.attribute(attr).value
      }
    end
  
    # # 引数のXPathでtextの配列を返す
    # def self.get_text(doc,xpath)
    #   doc.xpath(xpath).map { |node|
    #     # p node.text.gsub("\t", "").gsub("\n", "")
    #     node.text.gsub("\t", "").gsub("\n", "")
    #   }
    # end
    
    # 全ての製品一覧ページをダウンロードする
    def self.get_local_html(path,url)
      # nokogiri展開
      doc = nokogiri(path)
      # プロダクトの合計数の記載XPathは:doc.xpath('//span[@class = "toolbar-number"]')[2].text
      # 2ページ以降から,プロダクトの合計数/ページあたりの表示数である30の商を切り上げした数(全ページ数)まで,繰り返し
      (2..((doc.xpath('//span[@class = "toolbar-number"]')[2].text.to_f / 30).ceil)).each { |i|
        # pathの末尾の数字[0-9]+をページ数[i]に置き換えてfile_exist実行
        file_exist(path.sub(/[0-9]+/, i.to_s),url.chop<<i.to_s)
      }
    end

    # 引数の内容でjson形式で保存
    def self.write_json(json,product_url)
      write_file("src/thermaltake/product_url.json", {product_url: product_url}.to_json)
    end

    # 条件[*.html]でpathを検索し昇順に製品ページのURLをスクレイピングし2次元配列で返す
    def self.product_url_scraping(product_url)
      Dir.glob('src/thermaltake/*.html').sort.each { |html_path|
        # n番目のファイル|html_path|をnokogiriパーサーに通して一旦docに代入
        doc = nokogiri(html_path)
        # doc,XPathの検索条件,必要な場合属性[attr]を指定して実行し,各配列の末尾に結果を追加
        product_url.push(get_attr_value(doc,'//a[@class = "product-item-link"]',"href"))
        # product_url.push(get_attr_value(doc,'//a[@class = "product-image-photo default_image"]',"src"))
        # get_attr_value(doc,'//img[@class = "product-image-photo default_image"]',"src")
      }
      #配列の1次元化
      product_url.flatten!
    end

    # json形式ファイルを開く
    def self.open_json(json)
      File.open(json) do |file|
        JSON.load(file)
      end
    end

    # メインメソッド
    def self.thermaltake(path,url)
      # 空の配列を用意
      product_url = [] # 製品URL
      json = "src/thermaltake/product_url.json"
      # ページ数計算のために1ページ目のファイルがpathにダウンロードされているか確認
      file_exist(path,url)
      # 全ての製品一覧ページをダウンロードする
      get_local_html(path,url)
      # 条件[*.html]でpathを検索し昇順に
      product_url_scraping(product_url)
      # json形式で保存
      write_json(json,product_url)
      # デバッグ
      p "#{product_url.size},#{product_url[1]}"
      open_json(json).map { |url|
        
      }
    end
  end
end
