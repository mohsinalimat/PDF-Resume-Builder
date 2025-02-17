//
//  AutocompleteField.swift
//
//  Created by Filip Stefansson on 2020-10-09.
//

import Foundation
import UIKit

public enum SuggestionType {
    case Word
    case Sentence
}

@IBDesignable public class AutocompleteField: UITextField
{
    // MARK: - public properties

    /// The list of suggestions that the textfield should use when the user is typing.
    public var suggestions: [String] = [] {
        didSet {
            self.suggestionList = self.allSuggestions()
        }
    }

    /// The color of the autocompletion suggestion.
    @IBInspectable public var suggestionColor: UIColor = .apTextFieldTextColor.withAlphaComponent(0.4)

    /// The current suggestion shown. Read only.
    public private(set) var suggestion: String?

    /// Move the suggestion label in x or y. Sometimes there's a small difference between
    /// the suggestion and the real text, and this can be used to fix it.
    public var pixelCorrections: CGPoint = CGPoint(x: 0, y: 0);

    /// The type of autocomplete that should be used
    public var suggestionType: SuggestionType = .Sentence

    /// Set a horizontal padding for the the textfield. Automatically set when using a `borderStyle` of `.roundedRect`, `.bezel` or `.line`, because those have added padding.
    public var horizontalPadding: CGFloat = 0
    
    /// Set a delimiter to only show suggestions after the first occurance of that character
    public var delimiter: String?

    // whenever the text value is set, we need to update the suggestion
    // we do this by overriding the `text` property setter.
    override public var text: String? {
        didSet {
            self.textFieldDidChange(self)
        }
    }
    
    //MARK: - ResumeBuilder+Fix LeftViewMode
    public var leftViewPadding: CGFloat = 0
    
    public override var leftViewMode: UITextField.ViewMode {
        didSet{
            switch leftViewMode {
            case .always, .whileEditing:
                self.leftViewPadding = leftView?.frame.width ?? 0.0 + 35 // Default Value in case I forgot \±/
            default:
                break
            }
        }
    }
    
    //MARK: - End Fix

    override public var borderStyle: UITextField.BorderStyle {
        didSet {
            setPadding()
        }
    }

    // MARK: - private properties
    public var topText: String?{
        didSet{
            self.setupTopText()
        }
    }
    private var suggestionList: [String] = []

    /// The suggestion label
    private var label = UILabel()

    // MARK: - init functions

    override public init(frame: CGRect)
    {
        super.init(frame: frame)
        self.setup()
    }

    required public init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        self.setup()
    }

    /// Create an instance of a AutocompleteField.
    ///
    /// - Parameters:
    ///   - frame:       Frame of the textfield.
    ///   - suggestions: The list of suggestions that the textfield should use when the user is typing.
    public init(frame: CGRect, suggestions: [String])
    {
        super.init(frame: frame)
        self.suggestions = suggestions
        self.setup()
    }
    
    private func setupTopText() {
        
        guard let _topText = self.topText else { return }
        
        let topText: UILabel = {
            let label = UILabel()
            label.attributedText = NSAttributedString(string: _topText, attributes: [.font: UIFont(name: Theme.nunitoSansSemiBold, size: 14) as Any, .foregroundColor: UIColor.apTextFieldTextColor ])
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
        
        addSubview(topText)
        NSLayoutConstraint.activate([
            topText.bottomAnchor.constraint(equalTo: topAnchor, constant: 0),
            topText.leadingAnchor.constraint(equalTo: leadingAnchor),
            topText.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    // ovverride to set frame of the suggestion label whenever the textfield frame changes.
    public override func layoutSubviews()
    {
        // use `horizontalPadding` and `pixelCorrections` to calculte new frame
        self.label.frame = CGRect(x: self.horizontalPadding + self.pixelCorrections.x+leftViewPadding, y: self.pixelCorrections.y, width: self.frame.width - (self.horizontalPadding * 2), height: self.frame.height)
        super.layoutSubviews()
    }

    // MARK: - private methods

    private func setup() {
        self.addTarget(self, action: #selector(AutocompleteField.textFieldDidChange(_:)), for: .editingChanged)

        // create the label we use to
        self.createAutocompleteLabel()
    }

    /// Sets up the suggestion label with the same font styling and alignment as the textfield.
    private func createAutocompleteLabel()
    {
        self.label.lineBreakMode = .byClipping
        self.setPadding()
        self.addSubview(self.label)
    }

    private func setPadding() {
        self.label.lineBreakMode = .byClipping

        // if the textfield has one of the default styles,
        // we need to add some padding, otherwise there will
        // be a offset in x-led.
        switch self.borderStyle
        {
        case .roundedRect, .bezel, .line:
            self.horizontalPadding = 8
            break
        default:
            break
        }
    }

    /// Set content of the suggestion label.
    ///
    /// - parameters:
    ///     - text: Suggestion text
    private func setLabelText(text: String?)
    {
        guard let labelText = text else {
            label.attributedText = nil
            return
        }

        // don't show the suggestion if
        // 1. there's no text
        // 2. the text is longer than the suggestion
        if let inputText = self.text {
            if (inputText.count < 1 || inputText.count >= labelText.count) {
                label.attributedText = nil
                return
            }
        }

        let range = NSRange(location: 0, length: labelText.count);

        // create an attributed string instead of the regular one
        // in this way we can hide the letters in the suggestion
        // that the user has already written
        let attributedString = NSMutableAttributedString(
            string: labelText
        )
        attributedString.addAttributes(self.defaultTextAttributes, range: range)
        attributedString.addAttribute(.foregroundColor, value: self.suggestionColor, range: range);

        // hide the letters that are under the fields text
        // if the suggestion is abcdefgh and the user has written abcd
        // we want to hide those letters from the suggestion
        if let inputText = self.text
        {
            attributedString.addAttribute(NSAttributedString.Key.foregroundColor,
                value: UIColor.clear,
                range: NSRange(location: 0, length: inputText.count)
            )
        }

        label.attributedText = attributedString
        label.textAlignment = self.textAlignment
    }

    /// This method converts the suggestions list if suggestionType is sentence
    /// and an array with step of an suggestion if suggestionType is word
    private func allSuggestions() -> [String] {
        if (self.suggestionType == .Sentence) {
            return self.suggestions
        }

        var wordSuggestions: [String] = [];

        for suggestion in suggestions {
            let suggestions = suggestion.components(separatedBy: " ")
            for count in 0...suggestions.count - 1 {
                // the string where we will append all items
                var name = ""
                for i in 0...count {
                    if (i > 0) {
                        name = name.appending(" ")
                    }
                    name = name.appending(suggestions[i])
                }
                wordSuggestions.append(contentsOf: [name])
            }
        }

        wordSuggestions = wordSuggestions.sorted { $0.count < $1.count }

        return wordSuggestions
    }
    
    /// Splits text by a delimiter and returns an array with a max of two items containing everything
    /// before and after the first occurance of the delimiter
    /// test@em@il.com becomes ["test", "em@ail.com"]
    private func splitTextByDelimiter(text: String, delimiter: String) -> [String] {
        var parts = text.components(separatedBy: delimiter)
        let firstPart = parts[0]
        if (parts.count > 1) {
            parts.removeFirst()
            return [firstPart, parts.joined(separator: delimiter)]
        }
        return [firstPart]
    }

    /// Scans through the suggestions array and finds a suggestion that matches the searchTerm.
    ///
    /// - parameters:
    ///    - searchTerm: what to search for
    /// - returns A string or nil
    private func getSuggestion(text: String?) -> String?
    {
        guard var inputText = text else {
            return nil;
        }
        
        // if delimiter is set
        if let delimiterText = self.delimiter {
            // check if delimiter has been used
            let parts = self.splitTextByDelimiter(text: inputText, delimiter: delimiterText)
            if (parts.count > 1) {
                inputText = parts[1]
            } else {
                return nil
            }
        }
        
        if (inputText == "") {
            return nil;
        }

        if let suggestion = self.suggestionList.first(where: { $0.hasPrefix(inputText) }) {
            return suggestion
        }

        return nil
    }

    // MARK: - Events

    /// Triggered whenever the field text changes.
    ///
    /// - parameters:
    ///     - notification: The NSNotifcation attached to the event
    @objc func textFieldDidChange(_ textField: UITextField) {
        guard let text = self.text else {
            return
        }
        
        if var suggestion = getSuggestion(text: text) {
            // extra logic if we have a delimiter
            if let delimter = self.delimiter {
                // grab first part of text
                let prefix = self.splitTextByDelimiter(text: text, delimiter: delimter)[0]
                // add everything before the delimiter to the suggestion so it
                // works with our setLabelText method
                suggestion = prefix.appending(delimter).appending(suggestion)
            }
            
            self.suggestion = suggestion
            self.setLabelText(text: suggestion)
        } else {
            self.suggestion = text // To show texfield Test out of Suggestions
            self.setLabelText(text: nil)
        }
    }

    public override func textRect(forBounds bounds: CGRect) -> CGRect {
        return CGRect(x: bounds.origin.x + self.horizontalPadding+leftViewPadding, y: bounds.origin.y, width: bounds.size.width - (self.horizontalPadding * 2), height: bounds.size.height);
    }

    public override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return self.textRect(forBounds: bounds)
    }

    public override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return self.textRect(forBounds: bounds)
    }

    // remove target on deinit
    deinit {
        self.removeTarget(self, action: #selector(AutocompleteField.textFieldDidChange(_:)), for: .editingChanged)
    }
}
