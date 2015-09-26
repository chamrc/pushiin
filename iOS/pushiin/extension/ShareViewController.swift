//
//  ShareViewController.swift
//  pushiin
//
//  Created by  on 9/26/15.
//
//
import UIKit
import Social
import MobileCoreServices

extension NSMutableData {
    
    /*
     * Append string to NSMutableData
     *
     * Rather than littering my code with calls to `dataUsingEncoding` to convert
     * strings to NSData, and then add that data to the NSMutableData, this wraps
     * it in a nice convenient little extension to NSMutableData.
     * This converts using UTF-8.
     *
     * :param: string       The string to be added to the `NSMutableData`.
     */
    func appendString(string: String) {
        let data = string.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
        appendData(data!)
    }
}

class ShareViewController: SLComposeServiceViewController, NSURLSessionDelegate {
    
    var fileData: NSData?
    var fileUrl: NSURL?
    
    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        
        // Update number of characters remaining
        while self.contentText.characters.count > 8 {
            let id = self.textView
            let range = id.text.startIndex.advancedBy(8)..<id.text.endIndex
            id.text.removeRange(range)
        }
        self.charactersRemaining = 8 - self.contentText.characters.count
        
        /* The post button should be enabled only if we have the pdf data
           and the user has entered at least two characters of text */
        if let _ = fileData {
            var isPDF:Bool = false
            
            if self.fileData!.length >= 1024 { //only check if bigger
                var pdfBytes = [UInt8]()
                pdfBytes = [0x25, 0x50, 0x44, 0x46]
                
                let pdfHeader = NSData(bytes: pdfBytes, length: 4)
                let foundRange = fileData!.rangeOfData(pdfHeader, options: NSDataSearchOptions(), range: NSMakeRange(0, 1024))
                
                if foundRange.length > 0 {
                    isPDF = true
                }
            }
            
            if contentText.characters.count >= 2 && contentText.characters.count <= 8 {
                return isPDF
            }
        }
        return false
    }
    
    override func presentationAnimationDidFinish() {
        super.presentationAnimationDidFinish()
        
        // Retrieve last entered andrew ID
        placeholder = "Andrew ID"
        let path = NSBundle.mainBundle().pathForResource("Info", ofType: "plist")
        let dict = NSDictionary(contentsOfFile: path!)
        self.textView.text = dict!.objectForKey("andrewID") as! String
        self.charactersRemaining = 8 - self.contentText.characters.count
        
        // Convert shared content into data
        let content = extensionContext!.inputItems[0] as! NSExtensionItem
        let contentType = "public.url"
        
        for attachment in content.attachments as! [NSItemProvider] {
            if attachment.hasItemConformingToTypeIdentifier(contentType) {
                let dispatchQueue =
                dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
                dispatch_async(dispatchQueue, {
                    attachment.loadItemForTypeIdentifier(contentType,
                        options: nil,
                        completionHandler: {content, error in
                            if let data = content as? NSURL {
                                dispatch_async(dispatch_get_main_queue(), {
                                    self.fileUrl = data
                                    self.fileData = NSData(contentsOfURL: data)!
                                    self.validateContent()
                                })
                            }
                        }
                    )
                })
            }
            break
        }
    }
    
    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
        
        // Store andrew ID for future retrieval
        let path = NSBundle.mainBundle().pathForResource("Info", ofType: "plist")
        let dict: NSMutableDictionary = ["andrewID": self.contentText]
        dict.writeToFile(path!, atomically: false)
        
        // Create and send POST request
        let request = createRequest(self.contentText, fileData: self.fileData!)
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { data, response, error in
            if error != nil {
                // handle error here
                print(error)
                return
            }
            
            // if response was JSON, then parse it
            /*
             * We would want to provide feedback on whether the request was successfully
             * sent, but restrictions on functionality of app extentions make that hard
             */
            do {
                if let responseDictionary = try NSJSONSerialization.JSONObjectWithData(data!, options: []) as? NSDictionary {
                    print("success == \(responseDictionary)")
                    
                    // note, if you want to update the UI, make sure to dispatch that to the main queue, e.g.:
                    //
                    // dispatch_async(dispatch_get_main_queue()) {
                    //     // update your UI and model objects here
                    // }
                }
            } catch {
                print(error)
                
                let responseString = NSString(data: data!, encoding: NSUTF8StringEncoding)
                print("responseString = \(responseString)")
            }
        }
        task.resume()
        
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
        self.extensionContext!.completeRequestReturningItems([], completionHandler: nil)
    }
    
    override func configurationItems() -> [AnyObject]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return NSArray() as [AnyObject]
    }
    
    /*
     * Create request to pass to web service
     *
     * :param: userid   The userid to be passed to web service
     * :param: password The password to be passed to web service
     * :param: email    The email address to be passed to web service
     *
     * :returns:         The NSURLRequest that was created
     */
    func createRequest (andrewid: String, fileData: NSData) -> NSURLRequest {
        let param = ["id"  : andrewid]  // build your dictionary however appropriate
        let boundary = generateBoundaryString()
        let url = NSURL(string: "https://hackcmu-kahkhang.c9.io/print")!
        let request = NSMutableURLRequest(URL: url)
        
        request.HTTPMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.HTTPBody = createBodyWithParameters(param, filePathKey: "file", fileData: fileData, boundary: boundary)
        
        return request
    }
    
    /*
     * Create body of the multipart/form-data request
     *
     * :param: parameters   The optional dictionary containing keys and values to be passed to web service
     * :param: filePathKey  The optional field name to be used when uploading files.
     *                      If you supply paths, you must supply filePathKey, too.
     * :param: paths        The optional array of file paths of the files to be uploaded
     * :param: boundary     The multipart/form-data boundary
     *
     * :returns:            The NSData of the body of the request
     */
    func createBodyWithParameters(parameters: [String: String]?, filePathKey: String?, fileData: NSData, boundary: String) -> NSData {
        let body = NSMutableData()
        
        if parameters != nil {
            for (key, value) in parameters! {
                body.appendString("--\(boundary)\r\n")
                body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                body.appendString("\(value)\r\n")
            }
        }
        
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(filePathKey!)\"; filename=\"\(self.fileUrl!.lastPathComponent!)\"\r\n")
        body.appendString("Content-Type: application/pdf\r\n\r\n")
        body.appendData(fileData)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")
        
        return body
    }
    
    /*
     * Create boundary string for multipart/form-data request
     *
     * :returns:            The boundary string that consists of "Boundary-" followed by a UUID string.
     */
    func generateBoundaryString() -> String {
        return "Boundary-\(NSUUID().UUIDString)"
    }
    
    /*
     * Determine mime type on the basis of extension of a file.
     * This requires MobileCoreServices framework.
     *
     * :param: path         The path of the file for which we are going to determine the mime type.
     *
     * :returns:            Returns the mime type if successful.
     *                      Returns application/octet-stream if unable to determine mime type.
     */
    func mimeTypeForPath(path: String) -> String {
        let url = NSURL(fileURLWithPath: path)
        let pathExtension = url.pathExtension
        
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension! as NSString, nil)?.takeRetainedValue() {
            if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                return mimetype as String
            }
        }
        return "application/octet-stream";
    }
    
}
