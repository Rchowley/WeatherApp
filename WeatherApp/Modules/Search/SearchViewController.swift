//
//  SearchViewController.swift
//  WeatherApp
//
//  Created by Priyabrata Chowley on 13/10/19.
//  Copyright © 2019 Priyabrata Chowley. All rights reserved.
//

import UIKit
import ActionKit
import GooglePlaces
import LinearProgressBarMaterial

protocol SearchViewControllerDelegate {
    func select(_ place: GMSPlace)
    func select(_ recent: DB_Location)
}

final class SearchViewController: UIViewController {

    // MARK:- Variables -
    var objectViewModel: SearchViewModel = .init()
    var textFieldValue: String = "" {
        didSet {
            self.objectViewModel.strSearchKey = textFieldValue
        }
    }
    enum TableSection: Int, CaseIterable {
        case search, recents
        static subscript(_ index: Int)-> TableSection {
            return TableSection(rawValue: index) ?? .search
        }
    }
    var delegate: SearchViewControllerDelegate?
    lazy var progressView: LinearProgressBar = {
        let progressBar = LinearProgressBar()
        progressBar.backgroundColor = .white
        progressBar.progressBarColor = UIColor(red:0.21, green:0.60, blue:0.91, alpha:1.0)
        return progressBar
    }()
    
    // MARK:- IBOutlets -
    @IBOutlet weak var constHeightProgressView: NSLayoutConstraint!
    @IBOutlet weak var progressBar: UIView! {
        didSet {
            self.progressBar.addSubview(progressView)
            progressView.autoPinEdgesToSuperviewEdges()
        }
    }
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            self.tableView.dataSource = self
            self.tableView.delegate = self
            self.tableView.keyboardDismissMode = .onDrag
            self.tableView.estimatedRowHeight = 44
            self.tableView.rowHeight = UITableView.automaticDimension
            
            self.tableView.estimatedSectionHeaderHeight = 44
            self.tableView.sectionHeaderHeight = UITableView.automaticDimension
        }
    }
    @IBOutlet weak var textFieldSearch: UITextField! {
        didSet {
            self.textFieldSearch.text = self.objectViewModel.strSearchKey
            self.textFieldSearch.addControlEvent(.editingChanged) { [unowned self] in
                // https://stackoverflow.com/questions/24330056/how-to-throttle-search-based-on-typing-speed-in-ios-uisearchbar/29760716
                // to limit network activity, reloading the table 0.75 second after last key press.
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.search), object: nil)
                self.perform(#selector(self.search), with: nil, afterDelay: 0.75)
            }
        }
    }
    @IBOutlet weak var buttonBack: UIButton! {
        didSet {
            self.buttonBack.addControlEvent(.touchUpInside) { [unowned(safe) self] in
                self.actionBack()
            }
        }
    }
    @IBOutlet weak var viewBackSearchField: UIView! {
        didSet {
            viewBackSearchField.layer.cornerRadius = 6
            viewBackSearchField.layer.shadowColor = UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 0.02).cgColor
            viewBackSearchField.layer.shadowOpacity = 1
            viewBackSearchField.layer.shadowOffset = CGSize(width: 0, height: 2)
            viewBackSearchField.layer.shadowRadius = 5 / 2
            viewBackSearchField.layer.shadowPath = nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setup()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.textFieldSearch.becomeFirstResponder()
    }

    // MARK:- Setup -
    func setup() {
        setupData()
        setupUI()
    }
    func setupData() {
        
        progressView.startAnimation()
        self.objectViewModel.completion = { [weak self] type in
            guard let weakSelf = self else { return }
            switch type {
            case .success:
                DispatchQueue.main.async {
                    weakSelf.tableView.reloadData()
                }
            case .error: break
            case .loader(let startAnimate):
                if startAnimate {
                    weakSelf.constHeightProgressView.constant = 2
                    weakSelf.progressView.startAnimation()
                } else {
                    weakSelf.constHeightProgressView.constant = 0
                    weakSelf.progressView.stopAnimation()
                }
                weakSelf.view.layoutIfNeeded()
            }
        }
    }
    func setupUI() {
        
    }
        
    // MARK:- Actions -
    func actionBack() {
        if self.textFieldSearch.canResignFirstResponder { self.textFieldSearch.resignFirstResponder() }
        self.navigationController?.popViewController(animated: true)
    }
    @objc func search() {
        if let text = self.textFieldSearch.text {
            self.objectViewModel.strSearchKey = text
        }
    }
}

// MARK:- UITableViewDataSource -
extension SearchViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return TableSection.allCases.count
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch TableSection[section] {
        case .search: return self.objectViewModel.count
        case .recents: return self.objectViewModel.countForRecents
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchLocationTableViewCell", for: indexPath) as! SearchLocationTableViewCell
        
        switch TableSection[indexPath.section] {
        case .search: cell.location = self.objectViewModel[indexPath.row]
        case .recents: cell.dbLocation = self.objectViewModel.recentsPlaces[indexPath.row]
        }
        return cell
    }
}

// MARK:- UITableViewDelegate -
extension SearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch TableSection[indexPath.section] {
        case .search:
            self.objectViewModel.getPlace(at: indexPath) { [weak self] (place) in
                self?.delegate?.select(place)
            }
        case .recents: self.delegate?.select(self.objectViewModel.recentsPlaces[indexPath.row])
        }
        if let cell = tableView.cellForRow(at: indexPath) as? SearchLocationTableViewCell {
            cell.viewBackLabel.hero.id = self.viewBackSearchField.hero.id
            self.viewBackSearchField.hero.id = nil
        }
        self.navigationController?.popViewController(animated: true)
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {

        // back view for the header
        let headerView = UIView(frame: .init(x: 0, y: 0, width: tableView.bounds.width, height: 40))
        headerView.backgroundColor = .white

        // label for header
        let headerLabel = UILabel(frame: .init(x: 15, y: 0, width: view.bounds.width, height: headerView.bounds.height))
        headerLabel.font = .boldSystemFont(ofSize: 18)
        headerLabel.textColor = UIColor(red:0.21, green:0.60, blue:0.91, alpha:1.0)

        headerView.addSubview(headerLabel)

        
        switch TableSection[section] {
        case .search: headerLabel.text = "Search Results"
        case .recents: headerLabel.text = "Recents"
        }
        
        return headerView
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch TableSection[section] {
        case .search: return self.objectViewModel.count == 0 ? 0 : 40
        case .recents: return self.objectViewModel.countForRecents == 0 ? 0 : 40
        }
    }
}
