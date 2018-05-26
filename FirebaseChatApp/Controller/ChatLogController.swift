//
//  ChatLogController.swift
//  FirebaseChatApp
//
//  Created by Duminica Octavian on 26/05/2018.
//  Copyright © 2018 Duminica Octavian. All rights reserved.
//

import UIKit
import Firebase

class ChatLogController: UICollectionViewController, UITextFieldDelegate, UICollectionViewDelegateFlowLayout, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var user: User? {
        didSet {
            navigationItem.title = user?.name
            
            observeMessages()
        }
    }
    
    var messages = [Message]()
    
    func observeMessages() {
        guard let uid = Auth.auth().currentUser?.uid, let toId = user?.id else { return }
        
        let userMessagesRef = Database.database().reference().child("user-messages").child(uid).child(toId)
        userMessagesRef.observe(.childAdded, with: { (snapshot) in
            
            let messageId = snapshot.key
            let messagesRef = Database.database().reference().child("messages").child(messageId)
            messagesRef.observeSingleEvent(of: .value, with: { (snapshot) in
                
                guard let dictionary = snapshot.value as? [String: AnyObject] else {
                    return
                }
                
                let message = Message()
                message.text = dictionary["text"] as? String
                message.fromId = dictionary["fromId"] as? String
                message.toId = dictionary["toId"] as? String
                message.timeStamp = dictionary["timeStamp"] as? NSNumber
                message.imageUrl = dictionary["imageUrl"] as? String
                
                self.messages.append(message)
                
                DispatchQueue.main.async {
                    self.collectionView?.reloadData()
                }
               
            }, withCancel: nil)
            
            
        }, withCancel: nil)
    }
    
    lazy var inputTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Enter message..."
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        textField.autocapitalizationType = .sentences
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        return textField
    }()
   
    let cellId = "cellId"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView?.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        collectionView?.alwaysBounceVertical = true
        collectionView?.backgroundColor = .white
        collectionView?.register(ChatMessageCell.self, forCellWithReuseIdentifier: cellId)
        
        collectionView?.keyboardDismissMode = .interactive
        
//        setupInputComponents()
//
//        setupKeyboardObservers()
        
    }
    
    lazy var inputContainerView: UIView = {
        let containerView = UIView()
        containerView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 50)
        containerView.backgroundColor = .white
        
        let uploadImageView = UIImageView()
        uploadImageView.image = UIImage(named: "imageUploadIcon")
        uploadImageView.translatesAutoresizingMaskIntoConstraints = false
        uploadImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action:
            #selector(handleUploadTap)))
        uploadImageView.isUserInteractionEnabled = true
        containerView.addSubview(uploadImageView)
        
        uploadImageView.leftAnchor.constraint(equalTo: containerView.leftAnchor).isActive = true
        uploadImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        uploadImageView.widthAnchor.constraint(equalToConstant: 44).isActive = true
        uploadImageView.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        let sendButton = UIButton(type: .system)
        sendButton.setTitle("Send", for: .normal)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.addTarget(self, action: #selector(handleSend), for: .touchUpInside)
        containerView.addSubview(sendButton)
        
        sendButton.rightAnchor.constraint(equalTo: containerView.rightAnchor).isActive = true
        sendButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        sendButton.widthAnchor.constraint(equalToConstant: 80).isActive = true
        sendButton.heightAnchor.constraint(equalTo: containerView.heightAnchor).isActive = true
        
        containerView.addSubview(self.inputTextField)
        
        self.inputTextField.leftAnchor.constraint(equalTo: uploadImageView.rightAnchor, constant: 8).isActive = true
        self.inputTextField.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        self.inputTextField.rightAnchor.constraint(equalTo: sendButton.leftAnchor).isActive = true
        self.inputTextField.heightAnchor.constraint(equalTo: containerView.heightAnchor).isActive = true
        
        let separatorLineView = UIView()
        separatorLineView.backgroundColor = UIColor(r: 220, g: 220, b: 220)
        separatorLineView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(separatorLineView)
        
        separatorLineView.leftAnchor.constraint(equalTo: containerView.leftAnchor).isActive = true
        separatorLineView.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
        separatorLineView.widthAnchor.constraint(equalTo: containerView.widthAnchor).isActive = true
        separatorLineView.heightAnchor.constraint(equalToConstant: 1).isActive = true
        
        return containerView
    }()
    
    @objc func handleUploadTap() {
        let imagePickerController = UIImagePickerController()
        
        imagePickerController.delegate = self
        imagePickerController.allowsEditing = true
        
        present(imagePickerController, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        var selectedImageFromPicker: UIImage?
        
        if let editedImage = info["UIImagePickerControllerEditedImage"] as? UIImage {
            selectedImageFromPicker = editedImage
        } else if let originalImage = info["UIImagePickerControllerOriginalImage"] as? UIImage {
            selectedImageFromPicker = originalImage
        }
        
        if let selectedImage = selectedImageFromPicker {
            uploadToFirebaseStorageUsing(image: selectedImage)
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    private func uploadToFirebaseStorageUsing(image selectedImage: UIImage) {
        let imageName = NSUUID().uuidString
        
        let ref = Storage.storage().reference().child("message_images").child(imageName)
        
        if let uploadData = UIImageJPEGRepresentation(selectedImage, 0.2) {
            ref.putData(uploadData, metadata: nil) { (metadata, error) in
                
                if error != nil {
                    print(error as Any)
                    return
                }
                
                if let imageUrl = metadata?.downloadURL()?.absoluteString {
                    self.sendMessage(withImageUrl: imageUrl)
                }
            }
        }
    }
    
    private func sendMessage(withImageUrl imageUrl: String) {
        let ref = Database.database().reference().child("messages")
        let childRef = ref.childByAutoId() // this is for lists
        let toId = user!.id!
        let fromId = Auth.auth().currentUser!.uid
        let timeStamp: NSNumber = NSNumber(integerLiteral: Int(NSDate().timeIntervalSince1970))
        let values = ["imageUrl": imageUrl, "toId": toId, "fromId": fromId, "timeStamp": timeStamp] as [String : Any]
        childRef.updateChildValues(values)
        
        childRef.updateChildValues(values) { (error, ref) in
            
            if (error != nil) {
                print(error as Any)
                return
            }
            
            self.inputTextField.text = nil
            
            let userMessagesRef = Database.database().reference().child("user-messages").child(fromId).child(toId)
            
            let messageId = childRef.key
            userMessagesRef.updateChildValues([messageId: 1])
            
            let recipientUserMessagesRef = Database.database().reference().child("user-messages").child(toId).child(fromId)
            
            recipientUserMessagesRef.updateChildValues([messageId: 1])
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    override var inputAccessoryView: UIView? {
        get {
            return inputContainerView
        }
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
//    func setupKeyboardObservers() {
//        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
//
//         NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
//    }
//
//    override func viewDidDisappear(_ animated: Bool) {
//        super.viewDidAppear(animated)
//
//        NotificationCenter.default.removeObserver(self) // remove this to avoid memory leaks
//    }
    
//    @objc func handleKeyboardWillShow(notification: Notification) {
//        let keyboardFrame = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
//        let keyboardDuration = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue
//
//        containerViewBottomAnchor?.constant = -keyboardFrame!.height
//        UIView.animate(withDuration: keyboardDuration!) {
//            self.view.layoutIfNeeded() // animates constraints after modifying the constraints
//        }
//    }
//
//    @objc func handleKeyboardWillHide(notification: Notification) {
//        let keyboardDuration = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue
//
//        containerViewBottomAnchor?.constant = 0
//        UIView.animate(withDuration: keyboardDuration!) {
//            self.view.layoutIfNeeded() // animates constraints after modifying the constraints
//        }
//    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        collectionView?.collectionViewLayout.invalidateLayout()
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! ChatMessageCell
        
        let message = messages[indexPath.item]
        cell.textView.text = message.text
        
        setupCell(cell: cell, message: message)
        
        // modify the bubble view width
        if let text = message.text {
            cell.bubbleWidthAnchor?.constant = estimatedFramefForText(text: text).width + 32
        }
        
        
        return cell
    }
    
    private func setupCell(cell: ChatMessageCell, message: Message) {
        
        if let profileImageUrl = self.user?.profileImageUrl {
            cell.profileImageView.loadImageUsingCache(withUrlString: profileImageUrl)
        }
        
        if message.fromId == Auth.auth().currentUser?.uid {
            //blue
            cell.bubbleView.backgroundColor = ChatMessageCell.blueColor
            cell.textView.textColor = .white
            
            cell.bubbleViewRightAnchor?.isActive = true
            cell.bubbleViewLeftAnchor?.isActive = false
            cell.profileImageView.isHidden = true
        } else {
            cell.bubbleView.backgroundColor = UIColor(r: 240, g: 240, b: 240)
            cell.textView.textColor = .black
            
            cell.bubbleViewRightAnchor?.isActive = false
            cell.bubbleViewLeftAnchor?.isActive = true
            cell.profileImageView.isHidden = false
        }
        
        if let messageImageUrl = message.imageUrl {
            cell.messageImageView.loadImageUsingCache(withUrlString: messageImageUrl)
            cell.messageImageView.isHidden = false
            cell.bubbleView.backgroundColor = .clear
        } else {
            cell.messageImageView.isHidden = true
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        var height: CGFloat = 80
        
        // get estimated height
        if let text = messages[indexPath.item].text {
            height = estimatedFramefForText(text: text).height + 20
        }
        
        return CGSize(width: view.frame.width, height: height)
    }
    
    private func estimatedFramefForText(text: String) -> CGRect {
        let size = CGSize(width: 200, height: 1000)
        let options = NSStringDrawingOptions.usesFontLeading.union(.usesLineFragmentOrigin)
        
        return NSString(string: text).boundingRect(with: size, options: options, attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 16)], context: nil)
    }
    
    var containerViewBottomAnchor: NSLayoutConstraint?
    
//    func setupInputComponents() {
//        let containerView = UIView()
//        containerView.backgroundColor = .white
//        containerView.translatesAutoresizingMaskIntoConstraints = false
//
//        view.addSubview(containerView)
//
//        containerView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
//
//        containerViewBottomAnchor = containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
//        containerViewBottomAnchor?.isActive = true
//
//        containerView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
//        containerView.heightAnchor.constraint(equalToConstant: 50).isActive = true
//
//        let sendButton = UIButton(type: .system)
//        sendButton.setTitle("Send", for: .normal)
//        sendButton.translatesAutoresizingMaskIntoConstraints = false
//        sendButton.addTarget(self, action: #selector(handleSend), for: .touchUpInside)
//        containerView.addSubview(sendButton)
//
//        sendButton.rightAnchor.constraint(equalTo: containerView.rightAnchor).isActive = true
//        sendButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
//        sendButton.widthAnchor.constraint(equalToConstant: 80).isActive = true
//        sendButton.heightAnchor.constraint(equalTo: containerView.heightAnchor).isActive = true
//
//        containerView.addSubview(inputTextField)
//
//        inputTextField.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 8).isActive = true
//        inputTextField.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
//        inputTextField.rightAnchor.constraint(equalTo: sendButton.leftAnchor).isActive = true
//        inputTextField.heightAnchor.constraint(equalTo: containerView.heightAnchor).isActive = true
//
//        let separatorLineView = UIView()
//        separatorLineView.backgroundColor = UIColor(r: 220, g: 220, b: 220)
//        separatorLineView.translatesAutoresizingMaskIntoConstraints = false
//        containerView.addSubview(separatorLineView)
//
//        separatorLineView.leftAnchor.constraint(equalTo: containerView.leftAnchor).isActive = true
//        separatorLineView.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
//        separatorLineView.widthAnchor.constraint(equalTo: containerView.widthAnchor).isActive = true
//        separatorLineView.heightAnchor.constraint(equalToConstant: 1).isActive = true
//    }
    
    @objc func handleSend() {
        let ref = Database.database().reference().child("messages")
        let childRef = ref.childByAutoId() // this is for lists
        let toId = user!.id!
        let fromId = Auth.auth().currentUser!.uid
        let timeStamp: NSNumber = NSNumber(integerLiteral: Int(NSDate().timeIntervalSince1970))
        let values = ["text": inputTextField.text!, "toId": toId, "fromId": fromId, "timeStamp": timeStamp] as [String : Any]
        childRef.updateChildValues(values)
        
        childRef.updateChildValues(values) { (error, ref) in
            
            if (error != nil) {
                print(error as Any)
                return
            }
            
            self.inputTextField.text = nil
            
            let userMessagesRef = Database.database().reference().child("user-messages").child(fromId).child(toId)
            
            let messageId = childRef.key
            userMessagesRef.updateChildValues([messageId: 1])
            
            let recipientUserMessagesRef = Database.database().reference().child("user-messages").child(toId).child(fromId)
            
            recipientUserMessagesRef.updateChildValues([messageId: 1])
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        handleSend() // on enter send message
        return true
    }
}
